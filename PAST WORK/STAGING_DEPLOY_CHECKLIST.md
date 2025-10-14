# Staging Deployment Checklist - Final Push

## Pre-Deploy: IAM Permissions (5 minutes)

### 1. Grant Roles to Human Deployer

```bash
# Set your email
DEPLOYER_EMAIL="your-email@example.com"

# Grant 5 required roles
gcloud projects add-iam-policy-binding sierra-staging \
  --member="user:${DEPLOYER_EMAIL}" \
  --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding sierra-staging \
  --member="user:${DEPLOYER_EMAIL}" \
  --role="roles/cloudfunctions.developer"

gcloud projects add-iam-policy-binding sierra-staging \
  --member="user:${DEPLOYER_EMAIL}" \
  --role="roles/artifactregistry.reader"

gcloud projects add-iam-policy-binding sierra-staging \
  --member="user:${DEPLOYER_EMAIL}" \
  --role="roles/cloudbuild.builds.editor"

gcloud projects add-iam-policy-binding sierra-staging \
  --member="user:${DEPLOYER_EMAIL}" \
  --role="roles/run.admin"
```

### 2. Grant Roles to CI Principal (Cloud Build)

```bash
# Get project number
PROJECT_NUMBER=$(gcloud projects describe sierra-staging --format="value(projectNumber)")
CI_PRINCIPAL="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"

# Grant same 5 roles to CI
gcloud projects add-iam-policy-binding sierra-staging \
  --member="${CI_PRINCIPAL}" \
  --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding sierra-staging \
  --member="${CI_PRINCIPAL}" \
  --role="roles/cloudfunctions.developer"

gcloud projects add-iam-policy-binding sierra-staging \
  --member="${CI_PRINCIPAL}" \
  --role="roles/artifactregistry.reader"

gcloud projects add-iam-policy-binding sierra-staging \
  --member="${CI_PRINCIPAL}" \
  --role="roles/cloudbuild.builds.editor"

gcloud projects add-iam-policy-binding sierra-staging \
  --member="${CI_PRINCIPAL}" \
  --role="roles/run.admin"
```

### 3. Verify Permissions

```bash
gcloud projects get-iam-policy sierra-staging \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:${DEPLOYER_EMAIL}"
```

**Expected:** You should see all 5 roles listed.

**Wait:** 60-90 seconds for IAM propagation before deploying.

---

## Deploy Phase 1: Indexes (5-15 minutes)

### 1. Deploy Indexes

```bash
firebase deploy --only firestore:indexes --project sierra-staging
```

**Expected Output:**
```
✔  Deploy complete!

Firestore indexes deployed:
- (companyId, exceptionTags, clockInAt)
- (companyId, userId, clockInAt)
- ... [other indexes]

Indexes are building. Check status at:
https://console.firebase.google.com/project/sierra-staging/firestore/indexes
```

### 2. Monitor Index Build Status

Visit: https://console.firebase.google.com/project/sierra-staging/firestore/indexes

**Wait until all indexes show:** `ACTIVE` (not `CREATING`)

Estimated time: 5-15 minutes depending on existing data.

**Tip:** Refresh the page every 30 seconds. You can proceed once all are ACTIVE.

---

## Deploy Phase 2: Functions (3-5 minutes)

### 1. Deploy Functions

```bash
firebase deploy --only functions --project sierra-staging
```

**Expected Output:**
```
=== Deploying to 'sierra-staging'...

i  deploying functions
i  functions: ensuring required API cloudfunctions.googleapis.com is enabled...
i  functions: ensuring required API cloudbuild.googleapis.com is enabled...
✔  functions: required API cloudfunctions.googleapis.com is enabled
✔  functions: required API cloudbuild.googleapis.com is enabled
i  functions: preparing codebase default for deployment
i  functions: uploading build artifacts...
✔  functions: build artifacts uploaded

The following functions will deploy:
  clockIn(us-east4)
  clockOut(us-east4)
  bulkApproveTimeEntries(us-east4)
  createInvoiceFromTime(us-east4)
  autoClockOut(us-east4)
  adminAutoClockOutOnce(us-east4)
  editTimeEntry(us-east4)
  ... [other functions]

✔  functions[clockIn(us-east4)] Successful update operation.
✔  functions[clockOut(us-east4)] Successful update operation.
...
✔  Deploy complete!
```

### 2. Verify Deployment

```bash
firebase functions:list --project sierra-staging
```

**Expected:** All functions listed with `us-east4` region and status.

### 3. Check Recent Logs

```bash
firebase functions:log --project sierra-staging --limit 50
```

**Expected:** No ERROR logs related to deployment (some old logs may show).

---

## Post-Deploy Phase 1: Backfill Schema (2 minutes)

### 1. Start Firebase Shell

```bash
firebase functions:shell --project sierra-staging
```

### 2. Run Backfill Normalizer

```javascript
backfillNormalizeTimeEntries()
```

**Expected Response:**
```javascript
{
  processed: 150,
  updated: 8,
  errors: 0
}
```

- `processed`: Total time entries checked
- `updated`: Entries with legacy fields removed
- `errors`: Should be 0

**Purpose:** Removes legacy field aliases (clockIn → clockInAt, geo → clockInLoc, etc.)

### 3. Exit Shell

```javascript
.exit
```

---

## Post-Deploy Phase 2: Smoke Test (5 minutes)

### Open Functions Console

Visit: https://console.firebase.google.com/project/sierra-staging/functions

### Test 1: Clock In (Inside Geofence)

**Function:** `clockIn`

**Test Data:**
```json
{
  "jobId": "test-job-001",
  "lat": 37.7793,
  "lng": -122.4193,
  "accuracy": 10.0,
  "clientEventId": "smoke-test-001",
  "deviceId": "smoke-device"
}
```

**Expected Response (≤2s):**
```json
{
  "ok": true,
  "id": "some-entry-id"
}
```

**Check Logs:**
```bash
firebase functions:log --project sierra-staging --limit 10 | findstr "clockIn"
```

Expected log line:
```
clockIn: Success { uid: ..., jobId: test-job-001, entryId: ..., distanceM: 42.3, radiusM: 100, clientEventId: smoke-test-001, deviceId: smoke-device }
```

### Test 2: Clock In Idempotency (Reuse Same clientEventId)

**Function:** `clockIn`

**Test Data:** (Use SAME clientEventId as Test 1)
```json
{
  "jobId": "test-job-001",
  "lat": 37.7793,
  "lng": -122.4193,
  "accuracy": 10.0,
  "clientEventId": "smoke-test-001",
  "deviceId": "smoke-device"
}
```

**Expected Response:**
```json
{
  "ok": true,
  "id": "same-entry-id-as-test-1"
}
```

**Check Logs:**
Expected log line:
```
clockIn: Idempotent replay detected { uid: ..., entryId: ..., clientEventId: smoke-test-001, deviceId: smoke-device }
```

✅ **Validation:** Same entryId returned, no duplicate entry created.

### Test 3: Clock Out (Outside Geofence)

**Function:** `clockOut`

**Test Data:**
```json
{
  "timeEntryId": "entry-id-from-test-1",
  "lat": 37.7900,
  "lng": -122.4300,
  "accuracy": 15.0,
  "clientEventId": "smoke-test-002",
  "deviceId": "smoke-device"
}
```

**Expected Response:**
```json
{
  "ok": true,
  "warning": "Clocked out outside geofence (234.5m from job site). Entry flagged for review."
}
```

**Verify in Firestore:**
- Entry should have: `exceptionTags: ["geofence_out"]`
- Entry should have: `geoOkOut: false`

### Test 4: Exceptions Tab - Badge Counts

**Manual Check in Firestore Console:**
Visit: https://console.firebase.google.com/project/sierra-staging/firestore/data/~2FtimeEntries

**Query:**
```
companyId == "your-test-company-id"
exceptionTags array-contains "geofence_out"
approved == false
```

**Expected:** At least 1 result (the entry from Test 3).

### Test 5: Bulk Approve

**Function:** `bulkApproveTimeEntries`

**Test Data:**
```json
{
  "entryIds": ["entry-id-from-test-1"]
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
- Entry should have: `approved: true`
- Entry should have: `approvedBy: "admin-uid"`
- Entry should have: `approvedAt: <timestamp>`

### Test 6: Create Invoice from Time

**Function:** `createInvoiceFromTime`

**Test Data:**
```json
{
  "companyId": "your-test-company-id",
  "jobId": "test-job-001",
  "timeEntryIds": ["entry-id-from-test-1"],
  "hourlyRate": 50.0,
  "customerId": "test-customer-001",
  "dueDate": "2025-11-10",
  "notes": "Smoke test invoice"
}
```

**Expected Response:**
```json
{
  "ok": true,
  "invoiceId": "some-invoice-id",
  "totalHours": 2.5,
  "totalAmount": 125.0,
  "entriesLocked": 1
}
```

**Verify in Firestore:**
- Invoice created at `/invoices/{invoiceId}`
- Time entry has: `invoiceId: "some-invoice-id"`
- Time entry has: `invoicedAt: <timestamp>`
- Audit record created at `/audits/{auditId}`

### Test 7: Auto-Clockout (Dry-Run)

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

**Check Logs:**
```bash
firebase functions:log --project sierra-staging --limit 20 | findstr "runAutoClockOutOnce"
```

Expected log line:
```
runAutoClockOutOnce: Complete { processed: 0, dryRun: true }
```

### Test 8: App Check Enforcement (Optional - Requires Client)

**Method:** Use Flutter web client to trigger `clockIn` with App Check enabled.

**Expected Behavior:**
- Request succeeds with valid App Check token
- If token fails, ErrorMapper shows friendly message: "Please check your GPS signal and try again." (not raw "APP_CHECK_TOKEN_EXPIRED")

**Validation:** Check browser DevTools console for App Check debug token if in dev mode.

---

## Verification Checklist

Mark each item as complete:

- [ ] **Indexes deployed and ACTIVE** (all indexes show green in Console)
- [ ] **Functions deployed** (firebase functions:list shows all functions)
- [ ] **No deployment errors in logs** (firebase functions:log clean)
- [ ] **Backfill normalizer ran successfully** (updated > 0, errors = 0)
- [ ] **Clock In works** (≤2s response time)
- [ ] **Idempotency works** (same clientEventId returns same entryId)
- [ ] **Clock Out works** (geofence violation logged as exception)
- [ ] **Exception tagging works** (exceptionTags array populated)
- [ ] **Bulk approve works** (approved=true, audit trail created)
- [ ] **Create invoice works** (invoice created, entries locked)
- [ ] **Auto-clockout dry-run works** (logs clean, no index errors)
- [ ] **App Check active** (logs show no App Check failures)

---

## Performance Validation

### Check Latency Metrics

Visit: https://console.firebase.google.com/project/sierra-staging/functions/usage

**Metrics to Check:**
- `clockIn` p95 latency: **≤ 600ms** (target: ≤ 300ms)
- `clockOut` p95 latency: **≤ 600ms** (target: ≤ 300ms)
- `bulkApproveTimeEntries` latency: **≤ 2s** for 50 entries
- `createInvoiceFromTime` latency: **≤ 5s** for 100 entries

**Cold Start Check:**
With `minInstances: 1`, cold starts should be rare. Check "Invocations" chart for consistency.

---

## Go/No-Go Decision

### GREEN (Ship to Demo) ✅

All of these must be true:
- [x] All functions deployed successfully
- [x] All indexes ACTIVE
- [x] All smoke tests pass
- [x] p95 latency < 600ms for hot callables
- [x] No ERROR logs in recent history
- [x] App Check enforced (friendly error path validated)
- [x] Exceptions tab queries work (badge counts)
- [x] Bulk approve + invoice creation atomic

### YELLOW (Fix Before Demo) ⚠️

Any of these require attention:
- [ ] Latency spike (p95 > 600ms) → Check for cold starts, increase minInstances
- [ ] Index still CREATING after 15 min → Check Console for errors
- [ ] Idempotency not working → Verify clientEventId logic
- [ ] Geofence false positives → Adjust radiusM or accuracy threshold

### RED (Do Not Demo) 🛑

Any of these are blockers:
- [ ] Functions deployment failed (IAM issue, quota exceeded)
- [ ] Firestore indexes failed to build (check Console errors)
- [ ] Smoke test crashes (function errors)
- [ ] Data corruption (entries missing or duplicated)

---

## Deliverables for Review

Once all tests pass, capture:

### 1. Deploy Output (Last 20-30 Lines)

```bash
firebase deploy --only functions --project sierra-staging 2>&1 | tail -30
```

### 2. Functions List

```bash
firebase functions:list --project sierra-staging
```

### 3. Recent Logs (Last 50 Lines)

```bash
firebase functions:log --project sierra-staging --limit 50
```

### 4. Latency Screenshot

Screenshot from: https://console.firebase.google.com/project/sierra-staging/functions/usage

---

## Fast Escapes (If Blocked)

### Issue: IAM Propagation Delay

**Symptom:** "Permission denied" even after granting roles

**Fix:**
```bash
# Wait 60-90 seconds, then retry
sleep 90
firebase deploy --only functions --project sierra-staging
```

### Issue: Scheduler Invoke Permissions (403)

**Symptom:** `autoClockOut` scheduled function fails with 403

**Fix:**
```bash
# Grant run.invoker to Cloud Scheduler SA
gcloud run services add-iam-policy-binding autoClockOut \
  --region=us-east4 \
  --member="serviceAccount:sierra-staging@appspot.gserviceaccount.com" \
  --role="roles/run.invoker" \
  --project=sierra-staging
```

### Issue: Artifact Registry 403

**Symptom:** "Permission denied" accessing Artifact Registry

**Fix:**
```bash
# Grant artifactregistry.reader to Cloud Build SA
gcloud projects add-iam-policy-binding sierra-staging \
  --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
  --role="roles/artifactregistry.reader"
```

### Issue: Cold Start Spike

**Symptom:** First request after deploy takes 3-5s

**Fix:**
- `minInstances: 1` already set (functions will warm up in ~2 minutes)
- Trigger a manual warmup:
```bash
# Call clockIn once to warm the instance
curl -X POST https://us-east4-sierra-staging.cloudfunctions.net/clockIn \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)"
```

---

## Post-Demo: Prod Canary Prep

Once staging is **GREEN**, prepare for production canary:

1. **Tag the release:**
```bash
git tag -a v1.0.0-staging-validated -m "Staging validated: all smoke tests pass"
git push origin v1.0.0-staging-validated
```

2. **Document any config tweaks:**
   - Geofence radius adjustments
   - Accuracy thresholds
   - Rate limits
   - Alert thresholds

3. **Review RUNBOOK alerts:**
   - Enable 6 Cloud Monitoring alerts (3 critical, 3 warning)
   - Set notification channels (email, PagerDuty, Slack)

4. **Canary deployment script:**
```bash
# From: scripts/deploy_canary.sh
./scripts/deploy_canary.sh sierra-production 10  # 10% traffic to canary
```

---

## Status: READY TO DEPLOY

All code changes complete. Awaiting IAM permission grant to proceed.

**Last updated:** 2025-10-11
**Prepared by:** Claude Code
