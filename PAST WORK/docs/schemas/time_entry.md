# TimeEntry Schema

**Collection:** `/time_entries/{entryId}`
**Version:** 2.0
**Last Updated:** 2025-10-12

---

## Overview

Represents a single clock in/out record for a worker at a job site. Tracks both clock in and clock out events with geolocation validation.

**Purpose:**
- Track worker time at job sites
- Enforce geofence compliance for clock in/out
- Enable payroll calculations
- Provide audit trail for time worked

---

## Canonical Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `entryId` | `string` | ✅ | Document ID, unique entry identifier |
| `companyId` | `string` | ✅ | Company that owns this time entry |
| `userId` | `string` | ✅ | Worker user ID who clocked in/out |
| `jobId` | `string` | ✅ | Job site where work occurred |
| `clockInAt` | `Timestamp` | ✅ | Clock in timestamp (server time) |
| `clockInLocation` | `GeoPoint` | ✅ | GPS coordinates at clock in |
| `clockInGeofenceValid` | `boolean` | ✅ | Whether clock in was within geofence |
| `clockOutAt` | `Timestamp?` | ❌ | Clock out timestamp (null if still clocked in) |
| `clockOutLocation` | `GeoPoint?` | ❌ | GPS coordinates at clock out |
| `clockOutGeofenceValid` | `boolean?` | ❌ | Whether clock out was within geofence |
| `notes` | `string?` | ❌ | Optional worker notes |
| `createdAt` | `Timestamp` | ✅ | Entry creation timestamp |
| `updatedAt` | `Timestamp` | ✅ | Last update timestamp |

---

## State Lifecycle

A time entry progresses through these states:

1. **Active (Clocked In):**
   - `clockInAt` set, `clockOutAt` is null
   - Worker is currently on site

2. **Completed (Clocked Out):**
   - Both `clockInAt` and `clockOutAt` set
   - Worker has finished for the day

---

## TypeScript Interface

```typescript
// functions/src/types.ts
export interface TimeEntry {
  entryId: string;
  companyId: string;
  userId: string;
  jobId: string;
  clockInAt: FirebaseFirestore.Timestamp;
  clockInLocation: FirebaseFirestore.GeoPoint;
  clockInGeofenceValid: boolean;
  clockOutAt?: FirebaseFirestore.Timestamp;
  clockOutLocation?: FirebaseFirestore.GeoPoint;
  clockOutGeofenceValid?: boolean;
  notes?: string;
  createdAt: FirebaseFirestore.Timestamp;
  updatedAt: FirebaseFirestore.Timestamp;
}
```

---

## Dart Model

```dart
// lib/features/timeclock/domain/time_entry.dart
class TimeEntry {
  final String entryId;
  final String companyId;
  final String userId;
  final String jobId;
  final DateTime clockInAt;
  final GeoPoint clockInLocation;
  final bool clockInGeofenceValid;
  final DateTime? clockOutAt;
  final GeoPoint? clockOutLocation;
  final bool? clockOutGeofenceValid;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  TimeEntry({
    required this.entryId,
    required this.companyId,
    required this.userId,
    required this.jobId,
    required this.clockInAt,
    required this.clockInLocation,
    required this.clockInGeofenceValid,
    this.clockOutAt,
    this.clockOutLocation,
    this.clockOutGeofenceValid,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TimeEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TimeEntry(
      entryId: doc.id,
      companyId: data['companyId'] as String,
      userId: data['userId'] as String,
      jobId: data['jobId'] as String,
      clockInAt: (data['clockInAt'] as Timestamp).toDate(),
      clockInLocation: data['clockInLocation'] as GeoPoint,
      clockInGeofenceValid: data['clockInGeofenceValid'] as bool,
      clockOutAt: data['clockOutAt'] != null
          ? (data['clockOutAt'] as Timestamp).toDate()
          : null,
      clockOutLocation: data['clockOutLocation'] as GeoPoint?,
      clockOutGeofenceValid: data['clockOutGeofenceValid'] as bool?,
      notes: data['notes'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'companyId': companyId,
    'userId': userId,
    'jobId': jobId,
    'clockInAt': Timestamp.fromDate(clockInAt),
    'clockInLocation': clockInLocation,
    'clockInGeofenceValid': clockInGeofenceValid,
    'clockOutAt': clockOutAt != null ? Timestamp.fromDate(clockOutAt!) : null,
    'clockOutLocation': clockOutLocation,
    'clockOutGeofenceValid': clockOutGeofenceValid,
    'notes': notes,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };
}
```

---

## Firestore Security Rules

```javascript
match /time_entries/{entryId} {
  // Anyone in the same company can read time entries
  allow read: if authed()
    && resource.data.companyId == request.auth.token.companyId;

  // Only the worker themselves can create their own entry (Clock In via client)
  // BUT actually this should be server-side only via Cloud Function
  // Client creates via callable function, not direct Firestore write
  allow create: if false;  // Prevent client-side creates

  // Only Cloud Functions can update (Clock Out)
  allow update: if false;  // Prevent client-side updates

  // Only admins can delete time entries
  allow delete: if authed()
    && hasAnyRole(['admin'])
    && resource.data.companyId == request.auth.token.companyId;
}
```

**Rationale:**
- Time entries are too critical for direct client writes
- All Clock In/Out operations go through callable Cloud Functions
- Functions validate geofence and write with server timestamp
- Prevents time fraud and tampering

---

## Cloud Function Creation (Clock In)

```typescript
// functions/src/timeclock.ts
export const clockIn = onCall(async (req) => {
  const { jobId, lat, lng, accuracy } = req.data;
  const uid = req.auth.uid;
  const companyId = req.auth.token.companyId;

  // Validate geofence
  const job = await getJobDoc(jobId);
  const distance = haversine(
    { lat: job.geofence.lat, lng: job.geofence.lng },
    { lat, lng }
  );
  const effectiveRadius = job.geofence.radiusM + Math.max(accuracy, 15);
  const isValid = distance <= effectiveRadius;

  // Create entry
  const entryRef = db.collection('time_entries').doc();
  await entryRef.set({
    entryId: entryRef.id,
    companyId,
    userId: uid,
    jobId,
    clockInAt: FieldValue.serverTimestamp(),
    clockInLocation: new GeoPoint(lat, lng),
    clockInGeofenceValid: isValid,
    clockOutAt: null,
    clockOutLocation: null,
    clockOutGeofenceValid: null,
    notes: null,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  return { id: entryRef.id, success: true };
});
```

---

## Composite Indexes (REQUIRED)

### Index 1: Find Active Entry for User

```javascript
// Query: Get worker's current active entry
db.collection('time_entries')
  .where('userId', '==', uid)
  .where('companyId', '==', companyId)
  .where('clockOutAt', '==', null)
  .limit(1)
```

**Index Definition:**
```json
{
  "collectionGroup": "time_entries",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "userId", "order": "ASCENDING" },
    { "fieldPath": "companyId", "order": "ASCENDING" },
    { "fieldPath": "clockOutAt", "order": "ASCENDING" }
  ]
}
```

### Index 2: Query Time Entries for Job (Date Range)

```javascript
// Query: Get all entries for a job in date range
db.collection('time_entries')
  .where('jobId', '==', jobId)
  .where('companyId', '==', companyId)
  .where('clockInAt', '>=', startDate)
  .where('clockInAt', '<=', endDate)
  .orderBy('clockInAt', 'desc')
```

**Index Definition:**
```json
{
  "collectionGroup": "time_entries",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "jobId", "order": "ASCENDING" },
    { "fieldPath": "companyId", "order": "ASCENDING" },
    { "fieldPath": "clockInAt", "order": "DESCENDING" }
  ]
}
```

**Deploy:** `firebase deploy --only firestore:indexes`

---

## Queries

### Get Active Entry for Worker

```dart
final activeEntries = await db
  .collection('time_entries')
  .where('userId', isEqualTo: currentUserId)
  .where('companyId', isEqualTo: currentCompanyId)
  .where('clockOutAt', isEqualTo: null)
  .limit(1)
  .get();
```

### Get All Entries for Job (Today)

```typescript
const startOfDay = new Date();
startOfDay.setHours(0, 0, 0, 0);

const endOfDay = new Date();
endOfDay.setHours(23, 59, 59, 999);

const entries = await db
  .collection('time_entries')
  .where('jobId', '==', jobId)
  .where('companyId', '==', companyId)
  .where('clockInAt', '>=', startOfDay)
  .where('clockInAt', '<=', endOfDay)
  .orderBy('clockInAt', 'desc')
  .get();
```

### Get Worker's History (Last 30 Days)

```dart
final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));

final history = await db
  .collection('time_entries')
  .where('userId', isEqualTo: currentUserId)
  .where('companyId', isEqualTo: currentCompanyId)
  .where('clockInAt', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
  .orderBy('clockInAt', descending: true)
  .get();
```

---

## Validation

| Rule | Check |
|------|-------|
| Entry ID | Not empty |
| Company ID | Valid company exists |
| User ID | Valid user exists |
| Job ID | Valid job exists |
| Clock In | Must be set, not in future |
| Clock Out | If set, must be after clockInAt |
| GeoPoint | Valid latitude/longitude |
| Geofence Valid | Boolean |

---

## Migration Notes

**Legacy Fields (DEPRECATED):**
- ~~`workerId`~~ → Use `userId`
- ~~`clockIn`~~ → Use `clockInAt`
- ~~`clockOut`~~ → Use `clockOutAt`
- ~~`location`~~ → Split into `clockInLocation` and `clockOutLocation`
- ~~`geofenceValid`~~ → Split into `clockInGeofenceValid` and `clockOutGeofenceValid`

**Removal Date:** 2025-10-26

**Migration Script:** `tools/migrate_time_entries_v1_to_v2.cjs`

**Fallback Logic (Temporary):**
```typescript
// Support old flat structure during migration
const userId = entry.userId ?? entry.workerId;
const clockInAt = entry.clockInAt ?? entry.clockIn;
const clockOutAt = entry.clockOutAt ?? entry.clockOut;

if (!userId || !clockInAt) {
  throw new Error('Missing required time entry fields');
}
```

---

## Related Schemas

- [User](./user.md) - Worker who created this entry
- [Job](./job.md) - Job site where work occurred
- [Assignment](./assignment.md) - Authorization to work at this job

---

**See Also:**
- [Firestore GeoPoint Documentation](https://firebase.google.com/docs/reference/js/firestore_.geopoint)
- [Firestore Timestamp Documentation](https://firebase.google.com/docs/reference/js/firestore_.timestamp)
- [Firestore Composite Indexes](https://firebase.google.com/docs/firestore/query-data/indexing)
