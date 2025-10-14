# STAGING: GO Decision - Final Checklist

**Project:** sierra-painting-staging
**Date:** 2025-10-11
**Prepared by:** Claude Code
**Status:** 🟡 **AWAITING FINAL VALIDATION**

---

## ✅ Deployment Complete

### Phase 1: Firestore Indexes ✅

**Command:** `firebase deploy --only firestore:indexes --project sierra-painting-staging`

**Result:** ✅ **SUCCESS**
```
+ firestore: deployed indexes successfully for default database
+ Deploy complete!
```

**Key Index:** `(companyId, exceptionTags array, clockInAt DESC)` - NEW for Exceptions tab

**Status:** Deployed, building in background

**Action Required:** Verify all indexes show **ACTIVE** in Console:
https://console.firebase.google.com/project/sierra-painting-staging/firestore/indexes

---

### Phase 2: Cloud Functions ✅

**Command:** `firebase deploy --only functions --project sierra-painting-staging --force`

**Result:** ✅ **19 FUNCTIONS DEPLOYED**

**Critical Deployments:**
- ✅ `clockIn(us-east4)` - minInstances: 1, concurrency: 20, 10s timeout, 256MB
- ✅ `clockOut(us-east4)` - minInstances: 1, concurrency: 20, 10s timeout, 256MB
- ✅ `bulkApproveTimeEntries(us-east4)` - **NEW** callable for admin workflow
- ✅ `createInvoiceFromTime(us-east4)` - Atomic invoice creation
- ✅ `editTimeEntry(us-east4)` - With immutability guards (`ensureMutable`)
- ✅ `autoClockOut(us-east4)` - Scheduled hourly
- ✅ `adminAutoClockOutOnce(us-east4)` - Manual dry-run callable

**Region Note:**
- ✅ `onInvoiceCreated(us-central1)` - Correct region (co-located with Firestore)

**URLs:**
- api(us-east4): https://api-wb4yvudy5q-uk.a.run.app
- taskWorker(us-east4): https://taskworker-wb4yvudy5q-uk.a.run.app

---

## ⏸️ Pending Manual Validation

### 1. Backfill Normalizer

**Command:**
```bash
firebase functions:shell --project sierra-painting-staging
> backfillNormalizeTimeEntries()
```

**Expected Result:**
```javascript
{
  processed: 150,  // Total entries checked
  updated: 8,      // Entries with legacy fields removed
  errors: 0        // Must be 0
}
```

**Purpose:** Strips legacy field aliases (clockIn → clockInAt, geo → clockInLoc, etc.)

**Status:** ⏸️ **NOT YET RUN** (awaiting user execution)

**Requirement:** Must show `errors: 0` to proceed.

---

### 2. Smoke Tests (6 Required)

**Console:** https://console.firebase.google.com/project/sierra-painting-staging/functions

#### Test 1: Clock In (Inside Geofence)
```json
{"jobId":"<job-id>", "lat":37.7793, "lng":-122.4193, "accuracy":10, "clientEventId":"smoke-001", "deviceId":"smoke-device"}
```
✅ Expect: `{ok: true, id: "<entry-id>"}` in ≤2s

#### Test 2: Clock In Idempotency
(Same `clientEventId` as Test 1)
✅ Expect: Same entry ID, log shows "Idempotent replay detected"

#### Test 3: Clock Out (Outside Geofence)
```json
{"timeEntryId":"<entry-id>", "lat":37.7900, "lng":-122.4300, "accuracy":15, "clientEventId":"smoke-002", "deviceId":"smoke-device"}
```
✅ Expect: `{ok: true, warning: "...outside geofence..."}`, entry has `exceptionTags: ["geofence_out"]`

#### Test 4: Bulk Approve
```json
{"entryIds": ["<entry-id>"]}
```
✅ Expect: `{approved: 1, failed: 0}`, entry has `approved: true`, audit row created

#### Test 5: Create Invoice from Time
```json
{"companyId":"<id>", "jobId":"<id>", "timeEntryIds":["<id>"], "hourlyRate":50, "customerId":"<id>", "dueDate":"2025-11-10"}
```
✅ Expect: `{ok: true, invoiceId: "<id>"}`, entries have `invoiceId` set, invoice created

#### Test 6: Auto-Clockout Dry-Run
```json
{"dryRun": true}
```
✅ Expect: `{success: true, processed: 0}` (0 is normal if no long shifts), logs clean

**Status:** ⏸️ **NOT YET RUN** (awaiting user execution)

---

### 3. Performance Metrics

**Console:** https://console.firebase.google.com/project/sierra-painting-staging/functions/usage

**Targets:**

| Function | p95 Target | Alert Threshold | Status |
|----------|------------|-----------------|--------|
| clockIn | < 300ms | > 600ms | ⏸️ Check Console |
| clockOut | < 300ms | > 600ms | ⏸️ Check Console |
| bulkApprove | < 2s | > 5s | ⏸️ Check Console |
| createInvoice | < 3s | > 5s | ⏸️ Check Console |

**Cold Starts:** Should be **ZERO** (minInstances: 1 keeps functions warm)

**Status:** ⏸️ **NOT YET CHECKED** (awaiting user verification)

---

### 4. Error Log Check

**Console:** https://console.firebase.google.com/project/sierra-painting-staging/functions (Logs tab)

**Filter:** Severity = Error, Last 1 hour

**Expected:** Zero errors (or only test-related errors)

**Status:** ⏸️ **NOT YET CHECKED** (awaiting user verification)

---

## 📋 GO/NO-GO Criteria

### 🟢 GREEN = STAGING: GO

**All of these must be TRUE:**

- [x] ✅ Indexes deployed
- [x] ✅ All 19 functions deployed successfully
- [x] ✅ Hot callables configured (minInstances: 1, concurrency: 20)
- [x] ✅ New callable `bulkApproveTimeEntries` created
- [x] ✅ Immutability guards applied (`ensureMutable`)
- [x] ✅ Schema normalizer deployed
- [x] ✅ Firestore trigger in us-central1 (correct/co-located)
- [ ] ⏸️ Backfill normalizer run: `{ processed: N, updated: M, errors: 0 }`
- [ ] ⏸️ Test 1 PASS: Clock In inside geofence (≤2s)
- [ ] ⏸️ Test 2 PASS: Clock In idempotency (same entry ID)
- [ ] ⏸️ Test 3 PASS: Clock Out outside geofence (exceptionTags populated)
- [ ] ⏸️ Test 4 PASS: Bulk approve (approved=true, audit trail)
- [ ] ⏸️ Test 5 PASS: Create invoice (atomic, entries locked)
- [ ] ⏸️ Test 6 PASS: Auto-clockout dry-run (logs clean)
- [ ] ⏸️ p95 latency < 600ms for hot callables
- [ ] ⏸️ No ERROR logs in last hour
- [ ] ⏸️ All indexes ACTIVE (not CREATING)

**Current:** 7/17 GREEN, 10/17 PENDING

---

### 🟡 YELLOW = Fix Before Demo

- ⚠️ None currently

---

### 🔴 RED = Do Not Demo (Blockers)

- 🛑 None currently

---

## 🎯 Decision

**Current Status:** 🟡 **YELLOW - Awaiting Manual Validation**

**Reason:** Deployment complete, but manual smoke tests and backfill not yet executed.

**Next Steps:**

1. **Run Backfill Normalizer** (2 minutes)
   ```bash
   firebase functions:shell --project sierra-painting-staging
   > backfillNormalizeTimeEntries()
   ```

2. **Execute All 6 Smoke Tests** (10 minutes)
   - Use Functions Console
   - Follow test data in STAGING_VALIDATION_REPORT.md

3. **Check Metrics** (2 minutes)
   - Navigate to Console → Functions → Usage
   - Verify p95 < 600ms

4. **Check Logs** (1 minute)
   - Navigate to Console → Functions → Logs
   - Filter by Error severity
   - Verify zero errors

5. **Verify Indexes** (1 minute)
   - Navigate to Console → Firestore → Indexes
   - Verify all show ACTIVE status

**Total Time to GREEN:** ~15-20 minutes

---

## 🚀 Once GREEN → Actions

### 1. Stamp STAGING: GO ✅

Update this file:
```markdown
**Decision:** 🟢 **GREEN - STAGING: GO**
**Timestamp:** 2025-10-11 [time]
**Validated by:** [your name]
```

### 2. Tag the Release

```bash
git tag -a v1.0.0-demo -m "Staging validated: all smoke tests pass, p95 < 600ms"
git push origin v1.0.0-demo
```

### 3. Prepare Prod Deployment

Follow: `PROD_CANARY_PLAN.md`

**Steps:**
1. Deploy indexes to prod (5-15 min)
2. Deploy functions to prod (3-5 min)
3. Run backfill normalizer in prod
4. Quick smoke test (3 tests minimum)
5. Enable monitoring alerts (6 alerts)
6. Monitor for 24 hours

### 4. Enable Production Alerts

From `docs/RUNBOOK.md`:
- 3 critical alerts (page immediately)
- 3 warning alerts (daily summary)

### 5. Communicate Go-Live

**Internal team email:**
- Deployment time
- Version: v1.0.0-demo
- Dashboard link
- On-call contact
- Rollback procedure link

---

## 📊 Deployment Artifacts

**Available Now:**

1. **Functions List** ✅
   ```bash
   firebase functions:list --project sierra-painting-staging
   ```
   Output: 19 functions (18 in us-east4, 1 in us-central1)

2. **Deployment Logs** ✅
   - Indexes: "Deploy complete!"
   - Functions: "19 functions deployed successfully"

3. **Configuration Files** ✅
   - `firestore.indexes.json` - Updated with exceptions index
   - `functions/src/timeclock.ts` - Hot callable config
   - `functions/src/utils/schema_normalizer.ts` - Backfill function
   - `functions/src/admin/bulk_approve.ts` - New admin callable

**Pending:**

4. **Backfill Result** ⏸️
   - Format: `{ processed: N, updated: M, errors: 0 }`

5. **Smoke Test Results** ⏸️
   - 6 test outputs with entry IDs

6. **Latency Metrics Screenshot** ⏸️
   - Console → Functions → Usage
   - clockIn/clockOut p95 charts

7. **Firestore Screenshots** ⏸️
   - Entry with `exceptionTags: ["geofence_out"]`
   - Entry with `approved: true, approvedBy, approvedAt`
   - Entry with `invoiceId, invoicedAt`

---

## 📝 Quick Reference

**Staging Console:** https://console.firebase.google.com/project/sierra-painting-staging

**Key URLs:**
- Functions: /functions
- Firestore: /firestore/data
- Indexes: /firestore/indexes
- Logs: /functions (Logs tab)
- Metrics: /functions/usage

**Documentation:**
- Full validation report: `STAGING_VALIDATION_REPORT.md`
- Prod canary plan: `PROD_CANARY_PLAN.md`
- Operations runbook: `docs/RUNBOOK.md`
- Hardening summary: `HARDENING_SUMMARY.md`

---

## ⚡ Fast Fixes (If Needed)

### Issue: Index Still Creating After 15 Minutes

**Fix:**
```bash
# Check status
firebase firestore:indexes --project sierra-painting-staging

# If stuck, redeploy
firebase deploy --only firestore:indexes --project sierra-painting-staging
```

### Issue: Permission Error on Function Call

**Fix:**
- Verify admin custom claim is set: `auth.token.admin === true`
- Verify company ID matches: `auth.token.companyId === entry.companyId`

### Issue: Latency Spike (p95 > 600ms)

**Fix:**
```typescript
// Reduce concurrency from 20 → 12
{ region: 'us-east4', minInstances: 1, concurrency: 12 }
```

### Issue: App Check Failure

**Note:** Functions Console tests bypass App Check.
**Test via:** Flutter app with valid App Check token.
**Debug token:** Register in Console → App Check → Manage debug tokens.

---

## 🎯 Final Decision

**Current Status:** 🟡 **YELLOW**

**Blocking Items:** 10 pending validations

**Estimated Time to GREEN:** 15-20 minutes of manual testing

**Confidence Level:** HIGH (deployment successful, code validated)

**Recommendation:** Proceed with manual validation steps above.

**Once validated:** Mark STAGING: GO and proceed to prod canary.

---

**Last Updated:** 2025-10-11
**Next Review:** After manual validation complete
**Prepared by:** Claude Code
