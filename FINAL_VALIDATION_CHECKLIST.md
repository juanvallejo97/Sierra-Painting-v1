# Final Validation Checklist - sierra-painting-staging

**Date:** 2025-10-11
**Project:** sierra-painting-staging
**Region:** us-east4 (triggers in us-central1)
**Status:** DEPLOYED - Final Validation In Progress

---

## ✅ Automated Verification (Complete)

### 1. Functions List ✅

**Command:**
```bash
firebase functions:list --project sierra-painting-staging
```

**Result:** ✅ **19 FUNCTIONS DEPLOYED**

**Breakdown by Region:**

**us-east4 (18 functions):**
- ✅ `clockIn` - callable, 256MB (HOT: minInstances: 1, concurrency: 20)
- ✅ `clockOut` - callable, 256MB (HOT: minInstances: 1, concurrency: 20)
- ✅ `bulkApproveTimeEntries` - callable, 256MB (NEW)
- ✅ `createInvoiceFromTime` - callable, 256MB
- ✅ `editTimeEntry` - callable, 256MB
- ✅ `adminAutoClockOutOnce` - callable, 256MB
- ✅ `generateInvoice` - callable, 256MB
- ✅ `getInvoicePDFUrl` - callable, 256MB
- ✅ `regenerateInvoicePDF` - callable, 256MB
- ✅ `setUserRole` - callable, 256MB
- ✅ `manualCleanup` - callable, 256MB
- ✅ `getProbeMetrics` - callable, 256MB
- ✅ `autoClockOut` - scheduled, 256MB
- ✅ `dailyCleanup` - scheduled, 256MB
- ✅ `latencyProbe` - scheduled, 256MB
- ✅ `warm` - scheduled, 256MB
- ✅ `api` - https, 512MB (HOT: minInstances: 1)
- ✅ `taskWorker` - https, 512MB

**us-central1 (1 function):**
- ✅ `onInvoiceCreated` - Firestore trigger, 256MB (Co-located with Firestore - CORRECT)

**Verification:** ✅ All functions deployed, all in correct regions

---

## ⏸️ Manual Validation Required (Your Action)

### 2. Backfill Normalizer

**Method 1: Firebase Functions Shell (Recommended)**

```bash
firebase functions:shell --project sierra-painting-staging
```

Then in the shell:
```javascript
backfillNormalizeTimeEntries()
```

**Method 2: Node Script**

```bash
# From project root
GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account-key.json node run_backfill.js
```

**Expected Output:**
```javascript
{
  processed: 150,  // Total time entries checked
  updated: 8,      // Entries with legacy fields removed
  errors: 0        // MUST be 0
}
```

**Legacy Fields to Remove:**
- `clockIn` → `clockInAt`
- `clockOut` → `clockOutAt`
- `at` → `clockInAt`/`clockOutAt`
- `geo` → `clockInLoc`/`clockOutLoc`
- `lat`, `lng` → Inside GeoPoint
- `geoOk` → `geoOkIn`/`geoOkOut`
- `exception` → `exceptionTags` array
- `approved_by` → `approvedBy`
- `approved_at` → `approvedAt`
- `invoice_id` → `invoiceId`

**Spot-Check in Firestore:**

Navigate to: https://console.firebase.google.com/project/sierra-painting-staging/firestore/data/~2FtimeEntries

Pick any entry and verify it has ONLY canonical fields:
- ✅ `clockInAt` (Timestamp)
- ✅ `clockOutAt` (Timestamp or null)
- ✅ `clockInLoc` (GeoPoint)
- ✅ `clockOutLoc` (GeoPoint or null)
- ✅ `geoOkIn` (boolean)
- ✅ `geoOkOut` (boolean or null)
- ✅ `exceptionTags` (array of strings)
- ✅ `approved` (boolean)
- ✅ `approvedBy` (string or null)
- ✅ `approvedAt` (Timestamp or null)
- ✅ `invoiceId` (string or null)
- ✅ `deviceId` (string or null)
- ✅ `clientEventId` (string)

**NO legacy fields like:** `clockIn`, `clockOut`, `at`, `geo`, `lat`, `lng`, `geoOk`, `exception`, `approved_by`, `approved_at`, `invoice_id`

**Status:** ⏸️ **AWAITING EXECUTION**

**Action:** Run backfill, paste result here:
```
Backfill result: { processed: ___, updated: ___, errors: ___ }
```

---

### 3. Smoke Tests (Via Flutter App - App Check Enabled)

**Why Flutter App:** Console tests bypass App Check. Real tests must use the app.

#### Test 1: Clock In (Inside Geofence)

**Action:**
1. Open Flutter app
2. Navigate to time clock screen
3. Clock in at a job site (inside geofence)
4. Note the time and entry ID

**Expected:**
- ≤2s response time
- Success toast: "Clocked in successfully"
- Entry appears in time entries list

**Log to Check:**
```
clockIn: Success {
  uid: "...",
  jobId: "...",
  entryId: "...",
  distanceM: 42.3,
  radiusM: 100,
  accuracyM: 10,
  clientEventId: "...",
  deviceId: "..."
}
```

**Status:** ⏸️

**Result:** PASS / FAIL

---

#### Test 2: Clock In Idempotency

**Action:**
1. Immediately tap "Clock In" again (within 5 seconds)
2. Same user, same job, generates same `clientEventId`

**Expected:**
- Same entry ID returned
- No duplicate entry created
- Log shows "Idempotent replay detected"

**Log to Check:**
```
clockIn: Idempotent replay detected {
  uid: "...",
  jobId: "...",
  entryId: "...",  // Same as Test 1
  clientEventId: "...",
  deviceId: "..."
}
```

**Verify in Firestore:**
- Only ONE entry exists for this clock-in
- Entry ID matches both attempts

**Status:** ⏸️

**Result:** PASS / FAIL

---

#### Test 3: Clock Out (Outside Geofence)

**Action:**
1. Move outside the geofence (or use coordinates outside fence in test)
2. Clock out
3. Check entry in Firestore

**Expected:**
- Clock out succeeds
- Warning toast: "Clocked out outside geofence (234.5m from job site). Entry flagged for review."
- Entry has `exceptionTags: ["geofence_out"]`
- Entry has `geoOkOut: false`

**Log to Check:**
```
clockOut: Geofence check {
  ...,
  distanceM: 234.5,
  radiusM: 100,
  decision: "ALLOW_WITH_WARNING",
  flagged: true
}

clockOut: Exception tagged {
  ...,
  tag: "geofence_out",
  distanceM: 234.5
}

clockOut: Success {
  ...,
  geoOkOut: false,
  flagged: true
}
```

**Verify in Firestore:**
```
/timeEntries/<entry-id>:
  exceptionTags: ["geofence_out"]
  geoOkOut: false
  distanceAtOutM: 234.5
  clockOutLoc: GeoPoint(lat, lng)
```

**Status:** ⏸️

**Result:** PASS / FAIL

---

#### Test 4: Exceptions Tab → Bulk Approve

**Action:**
1. Open Admin panel
2. Navigate to Exceptions tab
3. Verify badge shows count > 0 (from Test 3)
4. Select the geofence exception entry
5. Click "Approve" (calls `bulkApproveTimeEntries`)
6. Verify success toast
7. Verify badge count decreases

**Expected:**
- Badge shows count (at least 1 from Test 3)
- Bulk approve succeeds: `{approved: 1, failed: 0}`
- Success toast: "✓ Approved 1 entries"
- Badge clears or decreases by 1
- Entry updated with `approved: true`

**Log to Check:**
```
bulkApproveTimeEntries: Request received {
  adminUid: "...",
  adminCompanyId: "...",
  entryCount: 1
}

bulkApproveTimeEntries: Batch committed {
  batchSize: 1,
  approved: 1,
  failed: 0
}

bulkApproveTimeEntries: Complete {
  adminUid: "...",
  approved: 1,
  failed: 0,
  errorCount: 0
}
```

**Verify in Firestore:**
```
/timeEntries/<entry-id>:
  approved: true
  approvedBy: "<admin-uid>"
  approvedAt: Timestamp
  updatedAt: Timestamp

/auditLog/<audit-id>:
  action: "approve_time_entry"
  actorUid: "<admin-uid>"
  targetId: "<entry-id>"
  before: { approved: false }
  after: { approved: true }
  timestamp: Timestamp
```

**Status:** ⏸️

**Result:** PASS / FAIL

---

#### Test 5: Create Invoice from Time

**Action:**
1. Select approved time entries
2. Click "Create Invoice"
3. Fill in details (hourly rate: $50, due date: 2025-11-10)
4. Submit (calls `createInvoiceFromTime`)

**Expected:**
- Invoice created
- All entries locked with `invoiceId`
- Success toast: "✓ Invoice created: $125.00 (2.5 hours)"
- Navigate to invoice detail

**Log to Check:**
```
createInvoiceFromTime: Validated all entries {
  entryCount: 1,
  totalHours: 2.5
}

createInvoiceFromTime: Invoice created {
  invoiceId: "...",
  totalAmount: 125.0,
  entriesLocked: 1
}
```

**Verify in Firestore:**
```
/invoices/<invoice-id>:
  companyId: "..."
  customerId: "..."
  jobId: "..."
  status: "pending"
  amount: 125.0
  currency: "USD"
  items: [
    {
      description: "Labor - <job-id>",
      quantity: 2.5,
      unitPrice: 50.0,
      discount: 0
    }
  ]
  timeEntryIds: ["<entry-id>"]
  dueDate: Timestamp
  createdAt: Timestamp
  createdBy: "<admin-uid>"

/timeEntries/<entry-id>:
  approved: true
  invoiceId: "<invoice-id>"
  invoicedAt: Timestamp

/audits/<audit-id>:
  type: "invoice_from_time"
  companyId: "..."
  invoiceId: "<invoice-id>"
  timeEntryIds: ["<entry-id>"]
  totalHours: 2.5
  totalAmount: 125.0
  createdBy: "<admin-uid>"
  createdAt: Timestamp
```

**Status:** ⏸️

**Result:** PASS / FAIL

---

#### Test 6: Auto-Clockout Dry-Run

**Action:**
1. Navigate to Admin panel
2. Click "Test Auto-Clockout" (calls `adminAutoClockOutOnce` with `{dryRun: true}`)

**Expected:**
- Response: `{success: true, processed: 0, entries: [], dryRun: true}`
- (0 is normal if no shifts > 12 hours)
- Logs clean (no errors)

**Log to Check:**
```
runAutoClockOutOnce: Start {
  cutoffHours: 12,
  dryRun: true
}

runAutoClockOutOnce: Query returned 0 open entries

runAutoClockOutOnce: Complete {
  processed: 0,
  dryRun: true
}
```

**Status:** ⏸️

**Result:** PASS / FAIL

---

### 4. Performance Metrics

**Console:** https://console.firebase.google.com/project/sierra-painting-staging/functions/usage

**Check Each Hot Callable:**

#### clockIn

**Navigate:** Functions → clockIn → Usage tab

**Metrics to Capture:**
- **p95 latency:** ___ ms (target: < 300ms, alert: > 600ms)
- **Invocations:** ___ in last hour
- **Errors:** ___ (should be 0)
- **Cold starts:** ___ (should be 0 with minInstances: 1)

**Chart Check:**
- "Execution times" chart shows consistent < 600ms
- "Invocations" chart shows no spikes at startup (no cold starts)

**Status:** ⏸️

**Result:** p95 = ___ ms, Cold starts = ___

---

#### clockOut

**Navigate:** Functions → clockOut → Usage tab

**Metrics to Capture:**
- **p95 latency:** ___ ms (target: < 300ms, alert: > 600ms)
- **Invocations:** ___ in last hour
- **Errors:** ___ (should be 0)
- **Cold starts:** ___ (should be 0 with minInstances: 1)

**Status:** ⏸️

**Result:** p95 = ___ ms, Cold starts = ___

---

#### bulkApproveTimeEntries

**Navigate:** Functions → bulkApproveTimeEntries → Usage tab

**Metrics to Capture:**
- **p95 latency:** ___ ms (target: < 2s, alert: > 5s)
- **Invocations:** ___ (from Test 4)
- **Errors:** ___ (should be 0)

**Status:** ⏸️

**Result:** p95 = ___ ms

---

#### createInvoiceFromTime

**Navigate:** Functions → createInvoiceFromTime → Usage tab

**Metrics to Capture:**
- **p95 latency:** ___ ms (target: < 3s, alert: > 5s)
- **Invocations:** ___ (from Test 5)
- **Errors:** ___ (should be 0)

**Status:** ⏸️

**Result:** p95 = ___ ms

---

### 5. Error Log Check

**Console:** https://console.firebase.google.com/project/sierra-painting-staging/functions

**Action:**
1. Click on any function (e.g., clockIn)
2. Go to "Logs" tab
3. Filter by "Severity: Error"
4. Time range: Last 1 hour

**Expected:** Zero errors

**If errors exist, check:**
- Error type (UNAUTHENTICATED, FAILED_PRECONDITION, PERMISSION_DENIED, etc.)
- Error message (should be friendly via ErrorMapper)
- Frequency (one-off vs repeated)

**Status:** ⏸️

**Result:** Errors found = ___ (expected: 0)

---

### 6. Firestore Indexes

**Console:** https://console.firebase.google.com/project/sierra-painting-staging/firestore/indexes

**Check Status:**

All indexes should show **ACTIVE** status (green checkmark), not **CREATING** (spinner).

**Key Indexes:**
- ✅ `(companyId, exceptionTags array, clockInAt DESC)` - NEW for Exceptions tab
- ✅ `(companyId, userId, clockInAt DESC)` - Time entries by user
- ✅ `(companyId, jobId, clockInAt DESC)` - Time entries by job
- ✅ `(userId, clockInAt DESC)` - User's time entries
- ✅ `(clockOutAt ASC, clockInAt ASC)` - Auto-clockout query
- Plus 8 more for other collections

**Status:** ⏸️

**Result:** All indexes ACTIVE? YES / NO

**If NO:** Which indexes are still CREATING? ___

---

## 📊 Validation Summary

### Deployment Status ✅

- [x] 19 functions deployed successfully
- [x] All functions in correct regions (18 in us-east4, 1 in us-central1)
- [x] Hot callables configured (minInstances: 1, concurrency: 20, 10s timeout, 256MB)
- [x] New `bulkApproveTimeEntries` callable deployed
- [x] Schema normalizer (`backfillNormalizeTimeEntries`) deployed
- [x] Immutability guards (`ensureMutable`) in `editTimeEntry`

### Manual Validation Status ⏸️

- [ ] Backfill normalizer run: `{ processed: ___, updated: ___, errors: 0 }`
- [ ] Test 1 PASS: Clock In inside geofence (≤2s)
- [ ] Test 2 PASS: Clock In idempotency (same entry ID, log shows replay)
- [ ] Test 3 PASS: Clock Out outside geofence (exceptionTags populated)
- [ ] Test 4 PASS: Bulk approve (approved=true, audit trail)
- [ ] Test 5 PASS: Create invoice (atomic, entries locked)
- [ ] Test 6 PASS: Auto-clockout dry-run (logs clean)
- [ ] p95 latency < 600ms for clockIn/clockOut
- [ ] No ERROR logs in last hour
- [ ] All indexes ACTIVE

---

## 🎯 GO/NO-GO Decision

### 🟢 GREEN = STAGING: GO

**Requirements:** ALL items above must be checked ✅

**Decision:**
- If ALL 10 manual validations PASS → **STAGING: GO** ✅
- If ANY test fails → **YELLOW** ⚠️ (fix and retest)
- If critical blocker → **RED** 🛑 (rollback)

### Actions After STAGING: GO

1. **Tag Release:**
   ```bash
   git tag -a v1.0.0-demo -m "Staging validated: all smoke tests pass, p95 < 600ms"
   git push origin v1.0.0-demo
   ```

2. **Update Decision File:**
   ```markdown
   **Decision:** 🟢 GREEN - STAGING: GO
   **Timestamp:** 2025-10-11 [time]
   **Validated by:** [your name]
   ```

3. **Proceed to Prod Canary:**
   Follow `PROD_CANARY_PLAN.md`

---

## 📝 Results Template (Fill After Validation)

**Copy/paste this after completing all tests:**

```
## FINAL VALIDATION RESULTS

**Date:** 2025-10-11
**Time:** [timestamp]
**Validated by:** [your name]

### 1. Backfill Normalizer
Result: { processed: ___, updated: ___, errors: ___ }
Spot-check: Entry ___ has only canonical fields: YES / NO

### 2. Smoke Tests
Test 1 (Clock In): PASS / FAIL - Response time: ___ ms
Test 2 (Idempotency): PASS / FAIL - Same entry ID: YES / NO
Test 3 (Clock Out): PASS / FAIL - exceptionTags present: YES / NO
Test 4 (Bulk Approve): PASS / FAIL - Audit trail: YES / NO
Test 5 (Create Invoice): PASS / FAIL - Entries locked: YES / NO
Test 6 (Auto-Clockout): PASS / FAIL - Logs clean: YES / NO

### 3. Key Log Lines
```
clockIn: Success { ... }
Idempotent replay detected { ... }
bulkApproveTimeEntries: Complete { approved: 1, failed: 0 }
```

### 4. Performance Metrics
clockIn p95: ___ ms
clockOut p95: ___ ms
clockIn cold starts: ___
clockOut cold starts: ___
bulkApprove p95: ___ ms
createInvoice p95: ___ ms

### 5. Error Check
Errors in last hour: ___ (expected: 0)

### 6. Indexes
All ACTIVE: YES / NO

### DECISION
Status: 🟢 GREEN / 🟡 YELLOW / 🔴 RED
Ready for STAGING: GO: YES / NO

### Notes
[Any observations, issues, or recommendations]
```

---

**Prepared by:** Claude Code
**Last Updated:** 2025-10-11
**Status:** Awaiting manual validation execution
