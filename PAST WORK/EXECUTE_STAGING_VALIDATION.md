# Execute Staging Validation - Quick Guide

**Project:** sierra-painting-staging
**Time Required:** 15 minutes
**Goal:** Validate deployment, stamp STAGING: GO, proceed to prod

---

## Step 1: Seed Database (Optional - 2 minutes)

**Only if database is empty or you need fresh test data:**

```bash
npm --prefix functions run seed:staging
```

**This creates:**
- Test company
- Test job site (with geofence)
- Worker user (for clock in/out)
- Admin user (for bulk approve, invoice)
- Assignment (worker → job)

**Skip if you already have test data.**

---

## Step 2: Smoke Tests via Flutter App (10 minutes)

**Important:** Use the Flutter app (not Functions Console) to test with App Check enabled.

### Test 1: Clock In (Inside Geofence)

**Action:**
1. Open Flutter app as **worker** user
2. Navigate to job site or ensure GPS is inside geofence
3. Tap "Clock In"
4. Note the response time

**Expected:**
- ✅ Success toast in ≤2s
- ✅ Entry appears in time entries list
- ✅ Note the `entryId` for next tests

**Capture:** Response time: ___ ms, Entry ID: ___

---

### Test 2: Idempotency (Same Client Event)

**Action:**
1. Immediately tap "Clock In" again (within 5 seconds)
2. Same user, same job
3. App should reuse same `clientEventId` on retry

**Expected:**
- ✅ Same entry ID returned (no duplicate created)
- ✅ Log shows "Idempotent replay detected"

**Capture:** Same entry ID? YES / NO

---

### Test 3: Clock Out (Outside Geofence)

**Action:**
1. Move GPS location outside geofence OR modify coords in test
2. Tap "Clock Out"

**Expected:**
- ✅ Clock out succeeds with warning toast
- ✅ Warning: "Clocked out outside geofence (XXXm from job site). Entry flagged for review."

**Verify in Firestore Console:**
Navigate to: `/timeEntries/<entry-id-from-test-1>`

Check fields:
```
exceptionTags: ["geofence_out"]
geoOkOut: false
clockOutLoc: GeoPoint(lat, lng)
distanceAtOutM: <distance>
```

**Capture:** exceptionTags present? YES / NO

---

### Test 4: Bulk Approve (Admin Exceptions Tab)

**Action:**
1. Open Flutter app as **admin** user
2. Navigate to Exceptions tab
3. Verify badge shows count > 0 (entry from Test 3)
4. Select the geofence exception entry
5. Tap "Approve" (calls `bulkApproveTimeEntries`)

**Expected:**
- ✅ Success toast: "✓ Approved 1 entries"
- ✅ Badge count decreases by 1
- ✅ Entry updated: `approved: true, approvedBy: <admin-uid>, approvedAt: <timestamp>`

**Verify in Firestore Console:**
Check `/timeEntries/<entry-id>`:
```
approved: true
approvedBy: "<admin-uid>"
approvedAt: Timestamp
```

Check `/auditLog/<audit-id>`:
```
action: "approve_time_entry"
actorUid: "<admin-uid>"
targetId: "<entry-id>"
```

**Capture:** Audit trail present? YES / NO

---

### Test 5: Create Invoice from Time

**Action:**
1. Select approved time entries (from Test 4)
2. Tap "Create Invoice"
3. Fill details:
   - Hourly rate: $50
   - Customer: (select or create)
   - Due date: 2025-11-10
4. Submit (calls `createInvoiceFromTime`)

**Expected:**
- ✅ Invoice created
- ✅ Success message with total amount
- ✅ Navigate to invoice detail

**Verify in Firestore Console:**
Check `/invoices/<invoice-id>`:
```
companyId: "..."
customerId: "..."
status: "pending"
amount: <calculated>
timeEntryIds: ["<entry-id>"]
```

Check `/timeEntries/<entry-id>`:
```
approved: true
invoiceId: "<invoice-id>"
invoicedAt: Timestamp
```

**Capture:** Entries locked with invoiceId? YES / NO

---

### Test 6: Auto-Clockout Dry-Run

**Run from terminal:**
```bash
firebase functions:call adminAutoClockOutOnce --data='{"dryRun":true}' --project sierra-painting-staging
```

**Expected Output:**
```json
{
  "success": true,
  "processed": 0,
  "entries": [],
  "dryRun": true
}
```

**Note:** `processed: 0` is normal if no shifts are open > 12 hours.

**Capture:** Success? YES / NO, Logs clean? YES / NO

---

## Step 3: Capture Proof Logs (2 minutes)

**Run in new terminal:**
```bash
firebase functions:log --project sierra-painting-staging --only clockIn,clockOut,bulkApproveTimeEntries --limit 50
```

**Look for these 3 log lines:**

1. **clockIn: Success**
```
clockIn: Success { uid: "...", jobId: "...", entryId: "...", distanceM: 42.3, radiusM: 100, clientEventId: "...", deviceId: "..." }
```

2. **Idempotent replay detected**
```
clockIn: Idempotent replay detected { uid: "...", entryId: "...", clientEventId: "...", deviceId: "..." }
```

3. **bulkApproveTimeEntries: Complete**
```
bulkApproveTimeEntries: Complete { adminUid: "...", approved: 1, failed: 0 }
```

**Copy/paste the actual log lines below.**

---

## Step 4: Verify Performance & Indexes (2 minutes)

### A. Performance Metrics

**Console:** https://console.firebase.google.com/project/sierra-painting-staging/functions/usage

**Check clockIn:**
1. Click on `clockIn` function
2. Navigate to "Metrics" tab
3. Check "Execution times" chart
4. Note p95 latency: ___ ms (target: < 300ms, alert: > 600ms)
5. Check "Invocations" chart - verify no cold start spikes

**Check clockOut:**
1. Click on `clockOut` function
2. Navigate to "Metrics" tab
3. Note p95 latency: ___ ms (target: < 300ms, alert: > 600ms)

**Capture:**
- clockIn p95: ___ ms
- clockOut p95: ___ ms
- Cold starts: 0 (YES / NO)

---

### B. Firestore Indexes

**Console:** https://console.firebase.google.com/project/sierra-painting-staging/firestore/indexes

**Verify all indexes show ACTIVE status (green checkmark):**

Key index to check:
- `(companyId, exceptionTags, clockInAt DESC)` - NEW for Exceptions tab

**Capture:** All indexes ACTIVE? YES / NO

---

## Step 5: Post Results

**Fill this template and paste back:**

```
## VALIDATION RESULTS

Backfill: { processed: 0, updated: 0, errors: 0 }

Smoke Tests:
1. Clock In: PASS – ___ ms
2. Idempotency: PASS – same id: YES/NO
3. Clock Out: PASS – exceptionTags present: YES/NO
4. Bulk Approve: PASS – audit OK: YES/NO
5. Create Invoice: PASS – entries locked w/ invoiceId: YES/NO
6. Auto-Clockout: PASS – logs clean: YES/NO

Logs:
[paste 3 proof lines from Step 3]

p95:
- clockIn: ___ ms
- clockOut: ___ ms
- Cold starts: 0 (YES/NO)

Indexes ACTIVE: YES/NO
```

---

## Quick Triage (If Anything Blips)

### UNAUTHENTICATED / App Check Error
- **Cause:** Testing via Functions Console (bypasses App Check)
- **Fix:** Test via Flutter app only
- **Verify:** ErrorMapper shows friendly message (not raw error)

### FAILED_PRECONDITION (Geofence/Accuracy)
- **Cause:** GPS accuracy > 50m or outside geofence
- **Fix:** Ensure accuracy ≤ 50m, move inside fence
- **Verify:** ErrorMapper shows hint: "GPS accuracy too low. Move to open area..."

### PERMISSION_DENIED
- **Cause:** User role mismatch or cross-company access
- **Fix:** Verify admin role: `auth.token.admin === true`
- **Verify:** Entry `companyId` matches user's `companyId`

### Missing Index
- **Cause:** Index still CREATING (not ACTIVE)
- **Fix:** Wait 5-15 minutes for index build
- **Verify:** Console → Firestore → Indexes shows ACTIVE

### Latency > 600ms
- **Cause:** Cold start or high concurrency
- **Fix:** Reduce concurrency from 20 → 12:
  ```typescript
  // In functions/src/timeclock.ts
  export const clockIn = functions.onCall({
    region: 'us-east4',
    minInstances: 1,
    concurrency: 12,  // Reduced from 20
    timeoutSeconds: 10,
    memory: '256MiB',
  }, async (req) => { ... });
  ```
  Then redeploy: `firebase deploy --only functions:clockIn,functions:clockOut --project sierra-painting-staging --force`

---

## After You Post Results

**If ALL GREEN:**
1. ✅ I'll stamp **STAGING: GO**
2. ✅ Tag release: `v1.0.0-demo`
3. ✅ Execute prod canary per `PROD_CANARY_PLAN.md`

**If YELLOW (1-2 failures):**
1. ⚠️ Apply fix from triage above
2. ⚠️ Retest failed item(s)
3. ⚠️ Repost results

**If RED (critical blocker):**
1. 🛑 Identify root cause
2. 🛑 Rollback if needed
3. 🛑 Fix and redeploy

---

**Ready to execute!** ⏱️ 15 minutes to STAGING: GO

---

## UI Notes (DeviceId + ClientEventId)

**Ensure your Flutter clock in/out handlers pass:**

```dart
// Clock In
final deviceId = await ref.read(deviceInfoServiceProvider).getDeviceId();
final clientEventId = Idempotency.newEventId();

await ref.read(timeclockApiProvider).clockIn(
  ClockInRequest(
    jobId: jobId,
    latitude: position.latitude,
    longitude: position.longitude,
    accuracy: position.accuracy,
    clientEventId: clientEventId,  // For idempotency
    deviceId: deviceId,              // For support debugging
  ),
);

// Clock Out
await ref.read(timeclockApiProvider).clockOut(
  ClockOutRequest(
    timeEntryId: activeEntry.id,
    latitude: position.latitude,
    longitude: position.longitude,
    accuracy: position.accuracy,
    clientEventId: Idempotency.newEventId(),
    deviceId: deviceId,
  ),
);
```

**These are already wired in the API layer** (`lib/features/timeclock/data/timeclock_api_impl.dart`), just ensure your UI buttons pass them.

---

**Prepared by:** Claude Code
**Date:** 2025-10-11
**Status:** Ready to execute
