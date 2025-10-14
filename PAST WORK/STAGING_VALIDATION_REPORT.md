# Staging Validation Report - sierra-painting-staging

**Date:** 2025-10-11
**Project:** sierra-painting-staging
**Region:** us-east4
**Status:** DEPLOYED - Awaiting Final Validation

---

## 📦 Deployment Summary

### Phase 1: Firestore Indexes ✅

**Command:**
```bash
firebase deploy --only firestore:indexes --project sierra-painting-staging
```

**Result:**
```
+ firestore: deployed indexes in firestore.indexes.json successfully for default database
+ Deploy complete!
```

**Status:** ✅ **SUCCESS**

**Console Link:** https://console.firebase.google.com/project/sierra-painting-staging/firestore/indexes

**Key Indexes Deployed:**
1. **(companyId, exceptionTags array, clockInAt DESC)** - NEW for Exceptions tab
2. (companyId, userId, clockInAt DESC) - Time entries by user
3. (companyId, jobId, clockInAt DESC) - Time entries by job
4. (userId, clockInAt DESC) - User's time entries
5. (clockOutAt ASC, clockInAt ASC) - Auto-clockout query
6. Plus 8 more for jobs, estimates, invoices, customers, assignments, clockEvents

**Action Required:** Verify all indexes show **ACTIVE** status (not CREATING) in Console.

---

### Phase 2: Cloud Functions Deployment ✅

**Command:**
```bash
firebase deploy --only functions --project sierra-painting-staging --force
```

**Result:**
```
+ functions[clockIn(us-east4)] Successful update operation.
+ functions[clockOut(us-east4)] Successful update operation.
+ functions[bulkApproveTimeEntries(us-east4)] Successful create operation.
+ functions[createInvoiceFromTime(us-east4)] Successful update operation.
+ functions[editTimeEntry(us-east4)] Successful update operation.
+ functions[autoClockOut(us-east4)] Successful update operation.
+ functions[adminAutoClockOutOnce(us-east4)] Successful update operation.
... [12 more functions]
+ Deploy complete!
```

**Status:** ✅ **SUCCESS - 19 Functions Deployed**

**Function URLs:**
- api(us-east4): https://api-wb4yvudy5q-uk.a.run.app
- taskWorker(us-east4): https://taskworker-wb4yvudy5q-uk.a.run.app

---

## 🔥 Deployed Functions Inventory

### Hot Path Callables (us-east4) - minInstances: 1

| Function | Region | Memory | Timeout | Concurrency | Status |
|----------|--------|--------|---------|-------------|--------|
| **clockIn** | us-east4 | 256MB | 10s | 20 | ✅ HOT |
| **clockOut** | us-east4 | 256MB | 10s | 20 | ✅ HOT |

**Performance Target:** p95 latency < 600ms (target: < 300ms)
**Cost:** ~$10/month for 2 warm instances

### Admin Callables (us-east4)

| Function | Region | Memory | Type | Status |
|----------|--------|--------|------|--------|
| **bulkApproveTimeEntries** | us-east4 | 256MB | callable | ✅ NEW |
| **createInvoiceFromTime** | us-east4 | 256MB | callable | ✅ |
| **editTimeEntry** | us-east4 | 256MB | callable | ✅ |
| **adminAutoClockOutOnce** | us-east4 | 256MB | callable | ✅ |
| generateInvoice | us-east4 | 256MB | callable | ✅ |
| getInvoicePDFUrl | us-east4 | 256MB | callable | ✅ |
| regenerateInvoicePDF | us-east4 | 256MB | callable | ✅ |
| setUserRole | us-east4 | 256MB | callable | ✅ |
| manualCleanup | us-east4 | 256MB | callable | ✅ |
| getProbeMetrics | us-east4 | 256MB | callable | ✅ |

### Scheduled Functions (us-east4)

| Function | Region | Schedule | Status |
|----------|--------|----------|--------|
| **autoClockOut** | us-east4 | Hourly | ✅ |
| dailyCleanup | us-east4 | Daily | ✅ |
| latencyProbe | us-east4 | Periodic | ✅ |
| warm | us-east4 | Every 5 min | ✅ |

### HTTP Endpoints (us-east4)

| Function | Region | Memory | minInstances | Status |
|----------|--------|--------|--------------|--------|
| api | us-east4 | 512MB | 1 | ✅ HOT |
| taskWorker | us-east4 | 512MB | 0 | ✅ |

### Firestore Triggers (us-central1) - Co-located with Firestore

| Function | Region | Trigger | Status | Note |
|----------|--------|---------|--------|------|
| onInvoiceCreated | us-central1 | Firestore create | ✅ | ✅ Correct region (co-located) |

**Note:** Firestore triggers should remain in **us-central1** as they are co-located with Firestore. No migration needed.

---

## 🧪 Phase 3: Backfill Schema Normalizer

**Command:**
```bash
firebase functions:shell --project sierra-painting-staging
> backfillNormalizeTimeEntries()
```

**Expected Result:**
```javascript
{
  processed: 150,  // Total time entries checked
  updated: 8,      // Entries with legacy fields removed
  errors: 0        // Should be 0
}
```

**Purpose:** Removes legacy field aliases:
- `clockIn` → `clockInAt`
- `clockOut` → `clockOutAt`
- `geo` → `clockInLoc`/`clockOutLoc`
- `geoOk` → `geoOkIn`/`geoOkOut`
- `exception` → `exceptionTags` array

**Status:** ⏸️ **MANUAL EXECUTION REQUIRED**

**Action Required:** Run the above command and capture the result.

---

## 🧪 Phase 4: Smoke Tests (Functions Console)

**Console URL:** https://console.firebase.google.com/project/sierra-painting-staging/functions

### Test 1: Clock In (Inside Geofence)

**Function:** `clockIn`

**Test Data:**
```json
{
  "jobId": "<your-seeded-job-id>",
  "lat": 37.7793,
  "lng": -122.4193,
  "accuracy": 10,
  "clientEventId": "smoke-001",
  "deviceId": "smoke-device"
}
```

**Expected Response (≤2s):**
```json
{
  "ok": true,
  "id": "<entry-id>"
}
```

**Expected Log:**
```
clockIn: Success { uid: ..., jobId: ..., entryId: ..., distanceM: 42.3, radiusM: 100, clientEventId: smoke-001, deviceId: smoke-device }
```

**Status:** ⏸️ **MANUAL EXECUTION REQUIRED**

---

### Test 2: Clock In Idempotency

**Function:** `clockIn`

**Test Data:** (Same `clientEventId` as Test 1)
```json
{
  "jobId": "<your-seeded-job-id>",
  "lat": 37.7793,
  "lng": -122.4193,
  "accuracy": 10,
  "clientEventId": "smoke-001",
  "deviceId": "smoke-device"
}
```

**Expected Response:**
```json
{
  "ok": true,
  "id": "<same-entry-id-as-test-1>"
}
```

**Expected Log:**
```
clockIn: Idempotent replay detected { uid: ..., entryId: ..., clientEventId: smoke-001, deviceId: smoke-device }
```

**Validation:** ✅ Same `entryId` returned, no duplicate entry created.

**Status:** ⏸️ **MANUAL EXECUTION REQUIRED**

---

### Test 3: Clock Out (Outside Geofence)

**Function:** `clockOut`

**Test Data:**
```json
{
  "timeEntryId": "<entry-id-from-test-1>",
  "lat": 37.7900,
  "lng": -122.4300,
  "accuracy": 15,
  "clientEventId": "smoke-002",
  "deviceId": "smoke-device"
}
```

**Expected Response:**
```json
{
  "ok": true,
  "warning": "Clocked out outside geofence (XXX.Xm from job site). Entry flagged for review."
}
```

**Verify in Firestore:**
- Entry should have: `exceptionTags: ["geofence_out"]`
- Entry should have: `geoOkOut: false`
- Entry should have: `distanceAtOutM: <distance>`

**Expected Log:**
```
clockOut: Geofence check { ..., decision: "ALLOW_WITH_WARNING", flagged: true }
clockOut: Exception tagged { ..., tag: "geofence_out", distanceM: 234.5 }
clockOut: Success { ..., geoOkOut: false, flagged: true }
```

**Status:** ⏸️ **MANUAL EXECUTION REQUIRED**

---

### Test 4: Bulk Approve Time Entries

**Function:** `bulkApproveTimeEntries`

**Test Data:**
```json
{
  "entryIds": ["<entry-id-from-test-1>"]
}
```

**Expected Response:**
```json
{
  "approved": 1,
  "failed": 0,
  "errors": [],
  "timestamp": "2025-10-11T..."
}
```

**Verify in Firestore:**
- Entry at `/timeEntries/<entry-id>` should have:
  - `approved: true`
  - `approvedBy: "<admin-uid>"`
  - `approvedAt: <timestamp>`
  - `updatedAt: <timestamp>`
- Audit record at `/auditLog/<audit-id>` should exist:
  - `action: "approve_time_entry"`
  - `actorUid: "<admin-uid>"`
  - `targetId: "<entry-id>"`
  - `before: { approved: false }`
  - `after: { approved: true }`

**Expected Log:**
```
bulkApproveTimeEntries: Request received { adminUid: ..., entryCount: 1 }
bulkApproveTimeEntries: Batch committed { batchSize: 1, approved: 1, failed: 0 }
bulkApproveTimeEntries: Complete { adminUid: ..., approved: 1, failed: 0 }
```

**Status:** ⏸️ **MANUAL EXECUTION REQUIRED**

---

### Test 5: Create Invoice from Time (Atomic)

**Function:** `createInvoiceFromTime`

**Test Data:**
```json
{
  "companyId": "<your-company-id>",
  "jobId": "<your-job-id>",
  "timeEntryIds": ["<entry-id-from-test-1>"],
  "hourlyRate": 50.0,
  "customerId": "<your-customer-id>",
  "dueDate": "2025-11-10",
  "notes": "Smoke test invoice"
}
```

**Expected Response:**
```json
{
  "ok": true,
  "invoiceId": "<invoice-id>",
  "totalHours": 2.5,
  "totalAmount": 125.0,
  "entriesLocked": 1
}
```

**Verify in Firestore:**
- Invoice at `/invoices/<invoice-id>` should exist:
  - `companyId: "<company-id>"`
  - `customerId: "<customer-id>"`
  - `jobId: "<job-id>"`
  - `status: "pending"`
  - `amount: 125.0`
  - `timeEntryIds: ["<entry-id>"]`
- Time entry at `/timeEntries/<entry-id>` should have:
  - `invoiceId: "<invoice-id>"`
  - `invoicedAt: <timestamp>`
- Audit record at `/audits/<audit-id>` should exist:
  - `type: "invoice_from_time"`
  - `invoiceId: "<invoice-id>"`
  - `timeEntryIds: ["<entry-id>"]`

**Expected Log:**
```
createInvoiceFromTime: Validated all entries { entryCount: 1, totalHours: 2.5 }
createInvoiceFromTime: Invoice created { invoiceId: ..., totalAmount: 125.0, entriesLocked: 1 }
```

**Status:** ⏸️ **MANUAL EXECUTION REQUIRED**

---

### Test 6: Auto-Clockout Dry-Run

**Function:** `adminAutoClockOutOnce`

**Test Data:**
```json
{
  "dryRun": true
}
```

**Expected Response:**
```json
{
  "success": true,
  "processed": 0,
  "entries": [],
  "dryRun": true
}
```

**Note:** `processed: 0` is expected if no shifts are open > 12 hours.

**Expected Log:**
```
runAutoClockOutOnce: Start { cutoffHours: 12, dryRun: true }
runAutoClockOutOnce: Query returned 0 open entries
runAutoClockOutOnce: Complete { processed: 0, dryRun: true }
```

**Status:** ⏸️ **MANUAL EXECUTION REQUIRED**

---

## 📊 Phase 5: Performance Validation

### Latency Metrics (Check in Console)

**Console URL:** https://console.firebase.google.com/project/sierra-painting-staging/functions/usage

**Target Metrics:**

| Function | p95 Latency | Target | Status |
|----------|-------------|--------|--------|
| clockIn | < 600ms | < 300ms | ⏸️ Check Console |
| clockOut | < 600ms | < 300ms | ⏸️ Check Console |
| bulkApproveTimeEntries | < 2s | < 2s | ⏸️ Check Console |
| createInvoiceFromTime | < 5s | < 5s | ⏸️ Check Console |

**Cold Start Check:**
With `minInstances: 1`, cold starts should be **ZERO** for `clockIn` and `clockOut`.

**Action Required:**
1. Navigate to Console → Functions → Usage
2. Select each hot callable (clockIn, clockOut)
3. Check "Execution times" chart
4. Verify p95 < 600ms
5. Verify "Invocations" chart shows consistent response times (no spikes)

---

### Error Rate Check

**Target:** 0 errors in deployment phase

**Action Required:**
1. Navigate to Console → Functions → Logs
2. Filter by "Severity: Error"
3. Check last 1 hour
4. Verify no errors related to:
   - Missing indexes (FAILED_PRECONDITION)
   - Permission issues (PERMISSION_DENIED)
   - Function crashes (Internal error)

**Expected:** Zero errors (or only test-related errors from manual smoke tests)

---

## 🔒 Security Hardening Verification

### 1. Immutability Guards ✅

**File:** `functions/src/edit-time-entry.ts:95-107`

**Status:** ✅ Applied

```typescript
if (!force) {
  ensureMutable(entry);  // Throws if approved or invoiced
}
```

**Test:** Try to edit an approved entry → Should fail with "Cannot modify approved time entry"

---

### 2. Company Scope Isolation ✅

**Functions with Company Checks:**
- ✅ `bulkApproveTimeEntries` - Line 128-137
- ✅ `createInvoiceFromTime` - Line 121-126
- ✅ `editTimeEntry` - Line 91-93

**Test:** Try to approve an entry from a different company → Should fail with "Entry belongs to different company"

---

### 3. App Check Enforcement ✅

**Client Config:**
- `.env.staging`: `ENABLE_APP_CHECK=true`
- `assets/config/public.env`: `ENABLE_APP_CHECK=true`
- ReCAPTCHA V3 site key: `6Lclq98rAAAAAHR8xPb6c8wYsk3BZ_K6g2ztur63`

**Error Mapping:**
- `lib/core/errors/error_mapper.dart` - Maps Firebase errors to friendly messages

**Test:** Call `clockIn` without App Check token (via curl) → Should fail gracefully with friendly message

**Note:** Functions Console tests bypass App Check. Test via Flutter app for full validation.

---

## 📋 Artifacts Checklist

### Required Captures:

- [x] **Functions List**
  ```bash
  firebase functions:list --project sierra-painting-staging
  ```
  ✅ Already captured (19 functions, all us-east4 except onInvoiceCreated in us-central1)

- [ ] **Backfill Normalizer Result**
  ```bash
  firebase functions:shell --project sierra-painting-staging
  > backfillNormalizeTimeEntries()
  ```
  ⏸️ Pending manual execution

- [ ] **Recent Logs (Last 50 Lines)**
  ```bash
  firebase functions:log --project sierra-painting-staging --limit 50
  ```
  ⏸️ Pending (use Console → Functions → Logs)

- [ ] **Firestore Screenshots**
  - Entry with `exceptionTags: ["geofence_out"]`
  - Entry with `approved: true, approvedBy, approvedAt`
  - Entry with `invoiceId, invoicedAt`
  - Audit record in `/auditLog`
  - Invoice in `/invoices`

- [ ] **Latency Metrics Screenshot**
  - Console → Functions → Usage
  - clockIn p95 latency
  - clockOut p95 latency
  - Invocations chart (no cold start spikes)

---

## 🎯 STAGING: GO Decision Matrix

### GREEN (Ship to Demo) ✅

**Code Deployment:**
- [x] Indexes deployed to sierra-painting-staging
- [x] All 19 functions deployed successfully
- [x] Hot callables configured (minInstances: 1, concurrency: 20, 10s timeout, 256MB)
- [x] New callable `bulkApproveTimeEntries` created and deployed
- [x] Immutability guards applied (`ensureMutable` in `editTimeEntry`)
- [x] Schema normalizer deployed and ready (`backfillNormalizeTimeEntries`)
- [x] Firestore triggers correctly in us-central1 (co-located with Firestore)

**Pending Validation:**
- [ ] Backfill normalizer run successfully (processed > 0, errors = 0)
- [ ] All 6 smoke tests pass
- [ ] p95 latency < 600ms for hot callables
- [ ] No ERROR logs in last hour
- [ ] Exceptions → Bulk Approve → Create Invoice works end-to-end

**DECISION:** 🟡 **YELLOW - Awaiting Manual Validation**

---

### YELLOW (Fix Before Demo) ⚠️

- ⚠️ None currently (Firestore trigger region is correct)

---

### RED (Blockers) 🛑

- 🛑 None currently

---

## 🚀 Next Steps

### Immediate Actions:

1. **Run Backfill Normalizer**
   ```bash
   firebase functions:shell --project sierra-painting-staging
   > backfillNormalizeTimeEntries()
   ```
   Expected: `{ processed: N, updated: M, errors: 0 }`

2. **Execute All 6 Smoke Tests**
   - Use Functions Console: https://console.firebase.google.com/project/sierra-painting-staging/functions
   - Follow test data above for each test
   - Capture responses and verify in Firestore

3. **Check Metrics**
   - Navigate to Console → Functions → Usage
   - Verify p95 latency < 600ms for clockIn/clockOut
   - Verify no cold start spikes

4. **Check Logs**
   - Navigate to Console → Functions → Logs
   - Filter by "Severity: Error"
   - Verify zero errors in last hour

5. **Capture Artifacts**
   - Backfill result line
   - Log snippet showing "Idempotent replay detected"
   - Log snippet showing "bulkApproveTimeEntries: Complete"
   - p95 metrics screenshot

---

### Once GREEN:

**Mark STAGING: GO** ✅

Then proceed to:

6. **Tag Release**
   ```bash
   git tag -a v1.0.0-demo -m "Staging validated: all smoke tests pass"
   git push origin v1.0.0-demo
   ```

7. **Prep Prod Canary**
   ```bash
   # Deploy indexes first
   firebase deploy --only firestore:indexes --project sierra-painting-prod
   # Wait for ACTIVE

   # Deploy functions
   firebase deploy --only functions --project sierra-painting-prod --force
   ```

8. **Enable RUNBOOK Alerts for Prod**
   - Configure 6 alerts (3 critical, 3 warning) from `docs/RUNBOOK.md`
   - Set notification channels (email, Slack)

9. **Run RUNBOOK Quick Smoke Against Prod Test Tenant**
   - Execute 5-minute smoke test from RUNBOOK
   - Verify p95 < 600ms
   - Verify no errors

---

## 📝 Summary

**Deployment Status:** ✅ **COMPLETE**

**Functions Deployed:** 19 (18 in us-east4, 1 in us-central1)

**Hot Callables:** 2 (clockIn, clockOut) with minInstances: 1

**New Features:**
- ✅ Bulk approve time entries (admin workflow)
- ✅ Create invoice from time (atomic operation)
- ✅ Schema normalizer (backfill ready)
- ✅ Immutability guards (approved/invoiced entries)
- ✅ Exceptions tab indexes (array filtering)

**Cost Impact:** ~$10/month for 2 warm instances

**Validation Status:** 🟡 **Awaiting Manual Smoke Tests**

**Blockers:** None

**Ready for:** Final smoke test execution → STAGING: GO

---

**Prepared by:** Claude Code
**Date:** 2025-10-11
**Version:** v1.0.0-pre-demo
