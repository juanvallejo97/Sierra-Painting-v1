# Validation Test Guide
**Build:** http://localhost:9030
**Date:** 2025-10-12
**Status:** Ready for End-to-End Testing

---

## Pre-Requisites Check

Before testing, verify Firestore data exists in Firebase Console:

### 1. User Document
**Path:** `/users/d5POlAllCoacEAN5uajhJfzcIJu2`

**Required Fields:**
```json
{
  "companyId": "test-company-staging",
  "role": "worker",
  "email": "worker@test.com",
  "displayName": "Test Worker"
}
```

**Check:** Firebase Console → Firestore Database → users collection → Find worker UID

---

### 2. Job Document
**Path:** `/jobs/test-job-staging`

**Required Fields:**
```json
{
  "companyId": "test-company-staging",
  "name": "SF Painted Ladies",
  "active": true,
  "geofence": {
    "latitude": 37.7793,
    "longitude": -122.4193,
    "radiusMeters": 150
  },
  "address": "710 Steiner St, San Francisco, CA"
}
```

**Check:** Firebase Console → Firestore Database → jobs collection → test-job-staging

---

### 3. Assignment Document
**Path:** `/assignments/{assignmentId}`

**Required Fields:**
```json
{
  "companyId": "test-company-staging",
  "userId": "d5POlAllCoacEAN5uajhJfzcIJu2",
  "jobId": "test-job-staging",
  "active": true,
  "assignedAt": "2025-10-12T00:00:00Z"
}
```

**Check:** Firebase Console → Firestore Database → assignments collection → Filter by userId

**Action:** If missing, create in Firebase Console or run seed script

---

## Test Scenarios

### Test 1: Clock In Success (Inside Geofence)

**Setup:**
1. Open **incognito browser** → http://localhost:9030
2. Open **DevTools Console** (F12)
3. Login as worker
4. Allow location permission

**Mock Location (if needed):**
- DevTools → Sensors → Override Geolocation
- Latitude: 37.7793
- Longitude: -122.4193

**Action:** Click "Clock In"

**Expected Behavior:**
- ✅ Button shows spinner and disables
- ✅ Response within 2 seconds
- ✅ Green toast: "✓ Clocked in successfully (ID: xxx)"
- ✅ Status card updates to "Currently Working"
- ✅ Job name appears: "SF Painted Ladies"
- ✅ Clock in time displays: "Clocked in at 10:42 AM"
- ✅ Elapsed time ticker starts: "0h 0m"
- ✅ Button turns orange: "Clock Out"
- ✅ Recent entries shows new entry

**Console Check:**
```
NO errors starting with "❌ Clock In Error:"
```

**Firebase Logs Check:**
```bash
firebase functions:log --project sierra-painting-staging --only clockIn --limit 10
```

Should see:
```
clockIn: Success
Entry created: <entryId>
```

**Capture:**
- [ ] Screenshot of success toast with entry ID
- [ ] Screenshot of updated status card
- [ ] Console logs (no errors)

---

### Test 2: Idempotency (Duplicate Prevention)

**Setup:** Continue from Test 1 (already clocked in)

**Action:** Refresh page (F5)

**Expected Behavior:**
- ✅ Status persists: Still shows "Currently Working"
- ✅ Same entry ID visible
- ✅ Elapsed time continues from correct clock-in time

**Firebase Check:**
```
Check /timeEntries collection - should have exactly 1 active entry for this worker
```

**Capture:**
- [ ] Screenshot showing status persists after refresh

---

### Test 3: Clock Out (Inside Geofence)

**Setup:** Continue from Test 2 (clocked in)

**Action:** Click "Clock Out"

**Expected Behavior:**
- ✅ Button shows spinner
- ✅ Response within 2 seconds
- ✅ Green toast: "✓ Clocked out successfully"
- ✅ Status updates to "Not Clocked In"
- ✅ Button turns green: "Clock In"
- ✅ Recent entries shows completed entry with duration

**Firebase Logs:**
```bash
firebase functions:log --project sierra-painting-staging --only clockOut --limit 10
```

Should see:
```
clockOut: Success
Duration: X.X hours
```

**Capture:**
- [ ] Screenshot of clock out success
- [ ] Entry in Recent Entries showing duration

---

### Test 4: Clock Out Outside Geofence (Exception Tagging)

**Setup:**
1. Clock in (Test 1)
2. Change mock location to outside geofence:
   - Latitude: 37.800
   - Longitude: -122.500
   - (About 2.5km away from job site)

**Action:** Click "Clock Out"

**Expected Behavior:**
- ✅ Button shows spinner
- ✅ Orange/yellow toast: "⚠ Clocked out: You were XX meters from the job site"
- ✅ Status updates to "Not Clocked In"
- ✅ Entry completes successfully

**Firebase Check:**
```
Entry in /timeEntries should have:
{
  "exceptionTags": ["geofence_out"],
  "clockOutGeofenceValid": false,
  "clockOutDistance": <meters>
}
```

**Capture:**
- [ ] Screenshot of warning toast
- [ ] Firestore document showing exceptionTags

---

### Test 5: Error Handling - No Assignment

**Setup:**
1. **Temporarily** delete or deactivate the assignment document in Firestore
2. Fresh incognito window → login

**Action:** Click "Clock In"

**Expected Behavior:**
- ✅ Red error toast: "No active job assigned. Contact your manager."
- ✅ Button returns to idle state (no spinner)
- ✅ Console shows debug error with clear message

**Console Expected:**
```
❌ Clock In Error: Exception
❌ Clock In Message: Exception: No active job assigned. Contact your manager.
```

**Restore:** Re-enable assignment after test

**Capture:**
- [ ] Screenshot of error toast
- [ ] Console log showing clear error

---

### Test 6: Error Handling - Outside Geofence on Clock In

**Setup:**
1. Mock location far outside geofence:
   - Latitude: 37.800
   - Longitude: -122.500

**Action:** Click "Clock In"

**Expected Behavior:**
- ✅ Red error toast: "You are XXXm from the job site. Move closer to clock in."
- ✅ Button returns to idle state
- ✅ No entry created

**Capture:**
- [ ] Screenshot of distance error

---

### Test 7: UI Responsiveness - Elapsed Time

**Setup:** Clock in

**Action:** Wait 1 minute

**Expected Behavior:**
- ✅ Elapsed time updates from "0h 0m" → "0h 1m"
- ✅ No manual refresh needed
- ✅ Updates continue every minute

**Capture:**
- [ ] Screenshot showing elapsed time ticking

---

### Test 8: Sign Out

**Setup:** From any screen

**Action:**
1. Click overflow menu (⋮) in top right
2. Select "Sign Out"

**Expected Behavior:**
- ✅ Navigates to /login
- ✅ Cannot access dashboard without re-login
- ✅ Auth state cleared

---

## Admin Flow Tests (Optional)

### Test 9: Admin View - Exceptions Tab

**Setup:**
1. Login as admin (UID: yqLJSx5NH1YHKa9WxIOhCrqJcPp1)
2. Navigate to Admin Review screen

**Expected Behavior:**
- ✅ Summary stats show counts
- ✅ "Outside Geofence" tab shows entries with geofence_out tag
- ✅ Entries are selectable
- ✅ Bulk actions available

---

## Performance Metrics

### Measure Response Times:

**Clock In:**
- Target: < 2 seconds
- Acceptable: < 3 seconds

**Clock Out:**
- Target: < 2 seconds
- Acceptable: < 3 seconds

**Provider Load:**
- activeJobProvider: < 500ms
- activeEntryProvider: < 500ms

### Check Firebase Metrics:

```bash
firebase functions:log --project sierra-painting-staging --limit 50
```

Look for:
- p95 latency < 600ms
- No cold starts (minInstances=1)
- Error rate < 1%

---

## Known Limitations (Deferred Features)

### Not Yet Implemented:
- ❌ Offline queue with Hive persistence
- ❌ Automatic replay on connectivity restoration
- ❌ PendingSyncChip UI indicator
- ❌ Provider caching (session-level)
- ❌ Timeouts on all long operations
- ❌ Admin bulk approve (skeleton only)
- ❌ Create invoice from time (skeleton only)

These features are documented but not blocking for initial validation. They can be implemented in Phase 2.

---

## Troubleshooting

### "Unable to complete. Please try again"

**Check Console for:**
```
❌ Clock In Error: <type>
❌ Clock In Message: <message>
```

**Common Causes:**
1. No user document with companyId
2. No active assignment
3. Job document missing or inactive
4. Firestore rules blocking read

**Fix:** Verify pre-requisites section above

---

### Status Shows "Not Clocked In" But Should Be Active

**Check:**
1. Firestore `/timeEntries` collection
2. Filter by userId and clockOutAt == null
3. If entry exists but UI doesn't show, check provider query

---

### "Network error" or Timeouts

**Check:**
1. Firebase project is sierra-painting-staging
2. Functions deployed to us-east4
3. App Check disabled in public.env for local testing
4. No ad blockers in incognito mode

---

## Success Criteria

### Must Pass (Blocker):
- [ ] Test 1: Clock In succeeds with toast + status update
- [ ] Test 2: Idempotency - refresh preserves state
- [ ] Test 3: Clock Out succeeds
- [ ] Test 4: Geofence exception tagged correctly
- [ ] Test 5: Error handling shows clear messages
- [ ] Test 8: Sign out works

### Should Pass (High Priority):
- [ ] Test 6: Distance error shown
- [ ] Test 7: Elapsed time ticks
- [ ] No console errors during happy path
- [ ] Response times < 2s

### Nice to Have (Can Defer):
- [ ] Offline queue implementation
- [ ] Admin bulk approve
- [ ] Create invoice flow

---

## Reporting Results

After running tests, provide:

1. **Test Results Matrix:**
   ```
   Test 1 (Clock In): ✅ PASS / ❌ FAIL
   Test 2 (Idempotency): ✅ PASS / ❌ FAIL
   Test 3 (Clock Out): ✅ PASS / ❌ FAIL
   ...
   ```

2. **Screenshots:**
   - Success toast with entry ID
   - Status card showing "Currently Working"
   - Error messages (if any)
   - Console logs

3. **Firebase Logs:**
   ```bash
   firebase functions:log --project sierra-painting-staging --only clockIn,clockOut --limit 20
   ```

4. **Performance Metrics:**
   - Clock In response time: X.Xs
   - Clock Out response time: X.Xs
   - Any errors or warnings

5. **Issues Found:**
   - Description
   - Steps to reproduce
   - Console error (if applicable)

---

## Next Steps After Validation

### If All Tests Pass:
1. Commit stability patch
2. Tag as `v1.0.0-mvp-stable`
3. **STAGING: GO** ✅
4. Plan Phase 2 features (offline queue, admin flows)

### If Tests Fail:
1. Document exact failure
2. Provide console logs
3. I'll fix and rebuild
4. Re-test until green

---

**End of Validation Guide**
**Ready to Execute Tests**
