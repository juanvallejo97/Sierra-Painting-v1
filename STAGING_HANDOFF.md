# Staging Validation Handoff - Ready for Manual Execution

**Project:** sierra-painting-staging
**Status:** ✅ Deployed, ⏸️ Awaiting Manual Validation
**Date:** 2025-10-11

---

## ✅ **Automated Setup Complete**

### 1. Project Context Set ✅
```bash
firebase use sierra-painting-staging
# Output: Now using project sierra-painting-staging
```

### 2. Deployment Verified ✅
**19 functions deployed and confirmed:**
- 18 in us-east4 (including hot callables: clockIn, clockOut with minInstances: 1)
- 1 in us-central1 (onInvoiceCreated - Firestore trigger, correct region)

### 3. Documentation Complete ✅
- ✅ EXECUTE_STAGING_VALIDATION.md - Step-by-step guide
- ✅ FINAL_VALIDATION_CHECKLIST.md - Detailed procedures
- ✅ PROD_CANARY_PLAN.md - Production deployment plan
- ✅ All hardening applied (immutability guards, schema normalizer, etc.)

---

## ⏸️ **Manual Execution Required (Your Action)**

**The following steps require Flutter app and Firebase Console access:**

### Step 1: Optional - Seed Database (2 minutes)

**Only if you need fresh test data:**

```bash
npm --prefix functions run seed:staging
```

This creates:
- Test company
- Test job with geofence
- Worker user (for clock operations)
- Admin user (for bulk approve, invoice)
- Assignment linking worker to job

**Skip if you have existing test data.**

---

### Step 2: Execute 6 Smoke Tests via Flutter App (10 minutes)

**Critical:** Use the Flutter app (not Console) to validate App Check.

#### Test 1: Clock In (Inside Geofence)

**Action in Flutter App:**
1. Login as worker user
2. Navigate to time clock screen
3. Ensure GPS is inside geofence OR at job site
4. Tap "Clock In"
5. Time the response

**Expected:**
- ✅ Success in ≤2s
- ✅ Entry ID displayed/stored

**Capture:**
- Response time: ___ ms
- Entry ID: ___

---

#### Test 2: Idempotency

**Action in Flutter App:**
1. Immediately tap "Clock In" again (within 5 seconds)
2. App reuses same `clientEventId` from Test 1

**Expected:**
- ✅ Same entry ID returned
- ✅ No duplicate entry created
- ✅ Log shows "Idempotent replay detected"

**Verify:**
- Same entry ID as Test 1? YES / NO

---

#### Test 3: Clock Out (Outside Geofence)

**Action in Flutter App:**
1. Modify GPS to be outside geofence OR physically move outside
2. Tap "Clock Out"

**Expected:**
- ✅ Clock out succeeds with warning
- ✅ Toast: "Clocked out outside geofence... Entry flagged for review."

**Verify in Firestore Console:**
Navigate to: `/timeEntries/<entry-id-from-test-1>`

Check:
```
exceptionTags: ["geofence_out"]
geoOkOut: false
distanceAtOutM: <number>
```

**Capture:**
- exceptionTags present? YES / NO

---

#### Test 4: Bulk Approve

**Action in Flutter App:**
1. Login as admin user
2. Navigate to Exceptions tab
3. Verify badge shows count > 0
4. Select the geofence exception from Test 3
5. Tap "Approve"

**Expected:**
- ✅ Success toast
- ✅ Badge count decreases
- ✅ Entry marked approved

**Verify in Firestore Console:**
Check `/timeEntries/<entry-id>`:
```
approved: true
approvedBy: "<admin-uid>"
approvedAt: <timestamp>
```

Check `/auditLog/<audit-id>`:
```
action: "approve_time_entry"
actorUid: "<admin-uid>"
targetId: "<entry-id>"
```

**Capture:**
- Approved? YES / NO
- Audit trail? YES / NO

---

#### Test 5: Create Invoice from Time

**Action in Flutter App:**
1. Select approved entries
2. Tap "Create Invoice"
3. Enter: Rate $50, Customer, Due date 2025-11-10
4. Submit

**Expected:**
- ✅ Invoice created
- ✅ Success message with total
- ✅ Navigate to invoice detail

**Verify in Firestore Console:**
Check `/invoices/<invoice-id>`:
```
status: "pending"
amount: <calculated>
timeEntryIds: ["<entry-id>"]
```

Check `/timeEntries/<entry-id>`:
```
invoiceId: "<invoice-id>"
invoicedAt: <timestamp>
```

**Capture:**
- Invoice created? YES / NO
- Entries locked? YES / NO

---

#### Test 6: Auto-Clockout Dry-Run

**Run in terminal:**
```bash
firebase functions:call adminAutoClockOutOnce --data="{\"dryRun\":true}" --project sierra-painting-staging
```

**Expected:**
```
{
  success: true,
  processed: 0,
  entries: [],
  dryRun: true
}
```

**Capture:**
- Success? YES / NO
- Logs clean? YES / NO

---

### Step 3: Capture Proof Logs (2 minutes)

**Run in terminal:**
```bash
firebase functions:log --project sierra-painting-staging --only clockIn,clockOut,bulkApproveTimeEntries --limit 50
```

**Find and copy these 3 log lines:**

1. `clockIn: Success { uid: "...", jobId: "...", entryId: "...", distanceM: ..., radiusM: 100, clientEventId: "...", deviceId: "..." }`

2. `clockIn: Idempotent replay detected { uid: "...", entryId: "...", clientEventId: "...", deviceId: "..." }`

3. `bulkApproveTimeEntries: Complete { adminUid: "...", approved: 1, failed: 0 }`

**Also verify:** No ERROR lines in logs

---

### Step 4: Check Metrics (2 minutes)

**Firebase Console:** https://console.firebase.google.com/project/sierra-painting-staging/functions/usage

**For clockIn function:**
1. Click `clockIn`
2. Go to "Metrics" tab
3. Check "Execution times" p95: ___ ms (target: < 300ms, alert: > 600ms)
4. Check "Invocations" chart for cold start spikes (should be 0)

**For clockOut function:**
1. Click `clockOut`
2. Go to "Metrics" tab
3. Check "Execution times" p95: ___ ms

**Capture:**
- clockIn p95: ___ ms
- clockOut p95: ___ ms
- Cold starts: 0? YES / NO

---

### Step 5: Verify Indexes (1 minute)

**Firebase Console:** https://console.firebase.google.com/project/sierra-painting-staging/firestore/indexes

**Check that all indexes show ACTIVE (green checkmark):**

Key index: `(companyId, exceptionTags, clockInAt DESC)`

**Capture:**
- All indexes ACTIVE? YES / NO

---

## 📝 **Results Template - Fill & Post Back**

```
## VALIDATION RESULTS

Smoke Tests:
1. Clock In: PASS/FAIL – ___ ms
2. Idempotency: PASS/FAIL – same id: YES/NO
3. Clock Out: PASS/FAIL – exceptionTags present: YES/NO
4. Bulk Approve: PASS/FAIL – audit OK: YES/NO
5. Create Invoice: PASS/FAIL – entries locked: YES/NO
6. Auto-Clockout: PASS/FAIL – { success: true, processed: ___ }

Proof Logs (paste 3 lines):
1. clockIn: Success ...
2. Idempotent replay detected ...
3. bulkApproveTimeEntries: Complete ...

p95 Metrics:
- clockIn: ___ ms
- clockOut: ___ ms
- Cold starts: 0 (YES/NO)

Indexes: ACTIVE (YES/NO)

Any issues? (describe or write NONE)
```

---

## 🚀 **Once You Post Results**

### If ALL GREEN ✅

**I will immediately:**

1. **Stamp STAGING: GO** in `STAGING_GO_DECISION.md`
2. **Tag release:**
   ```bash
   git tag -a v1.0.0-demo -m "Staging validated: all smoke tests pass, p95 < 600ms"
   git push origin v1.0.0-demo
   ```
3. **Execute Production Canary** per `PROD_CANARY_PLAN.md`:
   - Deploy indexes to sierra-painting-prod (5-15 min wait for ACTIVE)
   - Deploy functions to sierra-painting-prod
   - Run backfill normalizer in prod
   - Quick smoke (3 tests minimum)
   - Enable monitoring alerts (6 alerts from RUNBOOK)

**ETA to prod:** 30 minutes after your GREEN confirmation

---

### If YELLOW ⚠️ (1-2 failures)

**I will:**
1. Analyze the specific failure
2. Provide targeted fix
3. Guide retest of failed item(s)

**Common fixes:**

- **UNAUTHENTICATED:** Test via Flutter app, not Console
- **FAILED_PRECONDITION:** Check GPS accuracy ≤ 50m, inside geofence
- **PERMISSION_DENIED:** Verify admin role:
  ```bash
  firebase functions:call setUserRole --data="{\"uid\":\"<UID>\",\"role\":\"admin\",\"companyId\":\"<COMPANY_ID>\"}" --project sierra-painting-staging
  ```
- **Latency > 600ms:** Reduce concurrency to 12:
  ```bash
  # Edit functions/src/timeclock.ts, change concurrency: 20 → 12
  firebase deploy --only functions:clockIn,functions:clockOut --project sierra-painting-staging --force
  ```

---

### If RED 🛑 (Critical blocker)

**I will:**
1. Identify root cause from logs/error
2. Propose rollback if needed
3. Create fix plan with testing steps

---

## 📊 **Current Deployment Status**

**Functions:** ✅ 19 deployed (18 in us-east4, 1 in us-central1)

**Hot Callables:** ✅ Configured
- clockIn: minInstances: 1, concurrency: 20, 10s timeout, 256MB
- clockOut: minInstances: 1, concurrency: 20, 10s timeout, 256MB

**New Features:** ✅ Active
- bulkApproveTimeEntries (NEW)
- createInvoiceFromTime (atomic)
- ensureMutable guards (editTimeEntry)
- schema normalizer (ready for backfill)
- Exceptions tab indexes (active)

**Cost:** ~$10/month for 2 warm instances

---

## ⏱️ **Timeline**

- Your validation: 15 minutes
- Post results here
- My processing: 2 minutes (stamp GO, tag release)
- Prod canary execution: 30 minutes
- **Total to prod: ~47 minutes from your start**

---

## ✅ **Ready to Execute**

**You have everything you need:**
1. ✅ Project set to sierra-painting-staging
2. ✅ All functions deployed and verified
3. ✅ Complete execution guide (EXECUTE_STAGING_VALIDATION.md)
4. ✅ Results template above
5. ✅ Fast fixes documented

**Execute the 6 smoke tests, capture metrics, and paste results back.**

**I'm standing by to stamp STAGING: GO and initiate prod canary immediately.** 🚀

---

**Prepared by:** Claude Code
**Date:** 2025-10-11
**Status:** Awaiting your validation execution
