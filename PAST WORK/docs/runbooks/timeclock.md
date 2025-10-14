# Timeclock Troubleshooting Runbook

**Project:** Sierra Painting Staging
**Last Updated:** 2025-10-12
**Owner:** Engineering Team

---

## Quick Diagnostics

```bash
# Check recent clock in/out operations
firebase functions:log --project sierra-painting-staging --only clockIn,clockOut --lines 50

# View active time entries
firebase firestore:get time_entries --project sierra-painting-staging --where 'clockOutAt==null'

# Test function directly
firebase functions:shell --project sierra-painting-staging
> clockIn({jobId: "job_123", lat: 37.7793, lng: -122.4193, accuracy: 10, clientEventId: "test_001"})
```

---

## Scenario 1: Clock In Fails - "Outside Geofence"

**Symptoms:**
- Worker at job site but cannot clock in
- Error: "OUTSIDE_GEOFENCE" or "You must be at the job site to clock in"
- GPS shows correct location

**Diagnosis:**

1. **Verify job geofence configuration:**
```bash
# Get job document
firebase firestore:get jobs/<job-id> --project sierra-painting-staging

# Check fields:
# - location.lat: 37.7793
# - location.lng: -122.4193
# - geofenceRadiusM: 150 (default)
```

2. **Calculate distance:**
```python
from math import radians, cos, sin, asin, sqrt

def haversine(lat1, lon1, lat2, lon2):
    R = 6371000  # Earth radius in meters
    phi1, phi2 = radians(lat1), radians(lat2)
    dphi = radians(lat2 - lat1)
    dlambda = radians(lon2 - lon1)
    a = sin(dphi/2)**2 + cos(phi1)*cos(phi2)*sin(dlambda/2)**2
    return 2 * R * asin(sqrt(a))

# Example: Worker vs Job location
distance = haversine(37.7793, -122.4193, 37.7800, -122.4190)
print(f"Distance: {distance:.1f}m")
# If distance > 150m, geofence validation will fail
```

**Fix A: Increase Geofence Radius (Temporary)**

```bash
# Update job document
firebase firestore:update jobs/<job-id> \
  --data '{"geofenceRadiusM": 250}' \
  --project sierra-painting-staging
```

**Fix B: Worker GPS Inaccurate**

```dart
// Mobile app: Check GPS accuracy
final position = await Geolocator.getCurrentPosition(
  desiredAccuracy: LocationAccuracy.best,
);
print('GPS Accuracy: ${position.accuracy}m');
// If accuracy > 50m, GPS signal is poor
```

**Workaround:** Admin can manually approve time entry in Admin panel

**Expected Time:** 5-10 minutes

---

## Scenario 2: Clock In Fails - "Already Clocked In"

**Symptoms:**
- Worker tries to clock in, gets "ALREADY_CLOCKED_IN" error
- Worker claims they already clocked out

**Diagnosis:**

```bash
# Find worker's active time entry
firebase firestore:query time_entries \
  --where 'userId==<user-id>' \
  --where 'clockOutAt==null' \
  --project sierra-painting-staging
```

**Fix A: Force Clock Out (if entry is stale)**

```bash
# Get entry ID from diagnosis step
firebase firestore:update time_entries/<entry-id> \
  --data '{"clockOutAt": "2025-10-12T17:00:00Z", "clockOutNotes": "Admin force clock out", "exceptionTags": ["admin_clockout"]}' \
  --project sierra-painting-staging
```

**Fix B: Delete Duplicate Entry (if worker never clocked in)**

```bash
# WARNING: Only use if entry is invalid
firebase firestore:delete time_entries/<entry-id> --project sierra-painting-staging
```

**Expected Time:** 2-5 minutes

---

## Scenario 3: Duplicate Clock In Entries (Idempotency Failure)

**Symptoms:**
- Worker sees multiple clock in entries for same shift
- Database shows 2+ entries with same timestamp

**Diagnosis:**

```bash
# Find duplicate entries
firebase firestore:query time_entries \
  --where 'userId==<user-id>' \
  --where 'jobId==<job-id>' \
  --where 'clockInAt>=2025-10-12T08:00:00Z' \
  --project sierra-painting-staging
```

**Root Cause:** Client didn't send `clientEventId` or sent different IDs

**Fix: Delete Duplicate Entries**

```bash
# Keep the earliest entry, delete others
firebase firestore:delete time_entries/<duplicate-entry-id> --project sierra-painting-staging
```

**Prevention:** Ensure client sends stable `clientEventId`:
```dart
// GOOD: Stable device-based ID
final clientEventId = '${deviceId}_${DateTime.now().millisecondsSinceEpoch}';

// BAD: Random ID on each retry
final clientEventId = Uuid().v4();  // Different on every call!
```

**Expected Time:** 5 minutes

---

## Scenario 4: Clock Out Fails - "No Active Entry"

**Symptoms:**
- Worker tries to clock out, gets "NO_ACTIVE_ENTRY" error
- Worker is sure they clocked in

**Diagnosis:**

```bash
# Search for worker's recent entries
firebase firestore:query time_entries \
  --where 'userId==<user-id>' \
  --order-by 'clockInAt desc' \
  --limit 5 \
  --project sierra-painting-staging
```

**Fix A: Entry Already Clocked Out (Race Condition)**

```
# Check if entry has clockOutAt set
# If yes, inform worker clock out already succeeded
```

**Fix B: Entry Deleted or Missing**

```bash
# Worker must clock in again
# Investigate logs for deletion:
firebase functions:log --project sierra-painting-staging --search "<entry-id>"
```

**Expected Time:** 5-10 minutes

---

## Scenario 5: Missing Location Permissions

**Symptoms:**
- Clock in button disabled
- App shows "Location permission required"
- User claims permission was granted

**Diagnosis:**

```dart
// Check permission status
final permission = await Geolocator.checkPermission();
print('Location permission: $permission');
// LocationPermission.denied | deniedForever | whileInUse | always
```

**Fix A: Re-request Permission (iOS/Android)**

```dart
// Prompt user again
final permission = await Geolocator.requestPermission();
if (permission == LocationPermission.denied) {
  // Show settings prompt
  await Geolocator.openLocationSettings();
}
```

**Fix B: Permission Denied Forever (Android)**

```
User must manually enable in system settings:
Android: Settings → Apps → Sierra Painting → Permissions → Location → Allow
iOS: Settings → Sierra Painting → Location → While Using App
```

**Expected Time:** 2-5 minutes (user action required)

---

## Verification Commands

**Test Clock In Flow:**
```bash
firebase functions:shell --project sierra-painting-staging

# Inside shell:
> clockIn({
    jobId: "job_painted_ladies",
    lat: 37.7793,
    lng: -122.4193,
    accuracy: 10,
    clientEventId: "test_001",
    notes: "Manual test"
  })
```

**Test Clock Out Flow:**
```bash
> clockOut({
    timeEntryId: "<entry-id-from-clockin>",
    lat: 37.7793,
    lng: -122.4193,
    accuracy: 10,
    clientEventId: "test_002"
  })
```

**Query Active Entries:**
```bash
firebase firestore:query time_entries \
  --where 'clockOutAt==null' \
  --project sierra-painting-staging
```

---

## Common Error Codes

| Error | Meaning | Fix |
|-------|---------|-----|
| `OUTSIDE_GEOFENCE` | Worker location outside job radius | Increase radius or check GPS accuracy |
| `ALREADY_CLOCKED_IN` | Active time entry exists | Force clock out or delete duplicate |
| `NO_ACTIVE_ENTRY` | Cannot clock out (no open entry) | Worker must clock in first |
| `PERMISSION_DENIED` | Firestore rules block operation | Check user role claims |
| `IDEMPOTENCY_VIOLATION` | Duplicate clientEventId detected | Check for stale retries |

---

## Admin Actions Checklist

- [ ] Verified job geofence configuration
- [ ] Checked worker's GPS accuracy
- [ ] Reviewed recent function logs
- [ ] Confirmed user has correct role claims
- [ ] Tested clock in/out flow in emulator
- [ ] Documented issue in Slack/Discord

---

## References

- `functions/src/timeclock.ts` - Clock in/out implementation
- `lib/core/services/timeclock_service.dart` - Client-side service
- ADR-004: Timekeeping Model (docs/adr/004-timekeeping-model.md)

---

**Last Tested:** 2025-10-12 (staging environment)
**Next Review:** 2025-11-12
