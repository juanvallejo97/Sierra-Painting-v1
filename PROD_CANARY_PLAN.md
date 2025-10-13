# Production Canary Deployment Plan

**Target:** sierra-painting-prod (production)
**Strategy:** Canary deployment with gradual traffic ramp
**Prerequisites:** STAGING: GO confirmed

---

## Pre-Flight Checklist

### Staging Validation (Must be GREEN) ✅

- [ ] All 19 functions deployed to staging
- [ ] Backfill normalizer run successfully (errors: 0)
- [ ] All 6 smoke tests pass
- [ ] p95 latency < 600ms for hot callables
- [ ] Zero ERROR logs in staging
- [ ] Exceptions → Bulk Approve → Create Invoice end-to-end validated
- [ ] Firestore indexes all ACTIVE in staging
- [ ] App Check enforced and error paths friendly

**Decision:** Only proceed to prod if ALL items above are ✅ GREEN

---

## Phase 1: Tag the Release

```bash
# Tag the validated staging build
git tag -a v1.0.0-demo -m "Staging validated: all smoke tests pass, p95 < 600ms"
git push origin v1.0.0-demo

# Verify tag
git show v1.0.0-demo
```

**Purpose:** Creates a rollback point if prod deployment fails.

---

## Phase 2: Deploy to Production

### Step 1: Deploy Indexes First (5-15 minutes)

```bash
firebase deploy --only firestore:indexes --project sierra-painting-prod
```

**Expected Output:**
```
+ firestore: deployed indexes in firestore.indexes.json successfully
```

**Action:** Monitor index build status in Console:
https://console.firebase.google.com/project/sierra-painting-prod/firestore/indexes

**Wait for:** All indexes show **ACTIVE** status (not CREATING)

**Estimated Time:** 5-15 minutes depending on existing data

---

### Step 2: Deploy Functions with Hot Callables (3-5 minutes)

```bash
firebase deploy --only functions --project sierra-painting-prod --force
```

**Expected Output:**
```
+ functions[clockIn(us-east4)] Successful update operation.
+ functions[clockOut(us-east4)] Successful update operation.
+ functions[bulkApproveTimeEntries(us-east4)] Successful create operation.
+ functions[createInvoiceFromTime(us-east4)] Successful update operation.
... [15 more functions]
+ Deploy complete!
```

**Note:** `--force` flag required for minInstances configuration.

---

### Step 3: Run Backfill Normalizer (2 minutes)

```bash
firebase functions:shell --project sierra-painting-prod
> backfillNormalizeTimeEntries()
```

**Expected Result:**
```javascript
{
  processed: 500,
  updated: 12,
  errors: 0
}
```

**Purpose:** Clean up any legacy field aliases in production data.

---

## Phase 3: Production Smoke Test (5 minutes)

**Console URL:** https://console.firebase.google.com/project/sierra-painting-prod/functions

### Quick Smoke (3 Tests Minimum)

**Test 1: Clock In**
```json
{
  "jobId": "<prod-test-job-id>",
  "lat": 37.7793,
  "lng": -122.4193,
  "accuracy": 10,
  "clientEventId": "prod-smoke-001",
  "deviceId": "prod-smoke-device"
}
```
✅ Expect: `{ ok: true, id: "<entry-id>" }` in ≤2s

**Test 2: Clock In Idempotency**
(Same clientEventId as Test 1)
✅ Expect: Same entry ID, log shows "Idempotent replay detected"

**Test 3: Bulk Approve**
```json
{
  "entryIds": ["<entry-id-from-test-1>"]
}
```
✅ Expect: `{ approved: 1, failed: 0 }`

**Validation:**
- Check Firestore: Entry has `approved: true`
- Check logs: "bulkApproveTimeEntries: Complete"
- No ERROR logs

---

## Phase 4: Enable Monitoring Alerts

### Critical Alerts (Page Immediately)

**1. High Error Rate**
```
Metric: cloud.googleapis.com/functions/execution/error_count
Condition: Rate > 5 errors/minute for 5 minutes
Action: Page on-call engineer
```

**2. Function Timeout Spike**
```
Metric: cloud.googleapis.com/functions/execution/times
Condition: p95 > 10s for 5 minutes
Action: Page on-call engineer
```

**3. Auto-Clockout Failure**
```
Log Query: severity=ERROR AND "runAutoClockOutOnce"
Condition: Any ERROR logs
Action: Page on-call engineer
```

### Warning Alerts (Review Daily)

**4. Elevated Latency**
```
Metric: cloud.googleapis.com/functions/execution/times
Condition: p95 > 600ms for clockIn/clockOut
Action: Daily summary email
```

**5. Geofence Exception Rate**
```
Log Query: "Outside geofence" OR "GPS accuracy too low"
Condition: > 20% of clock attempts
Action: Daily summary email
```

**6. Idempotent Replay Rate**
```
Log Query: "Idempotent replay detected"
Condition: > 5% of clock attempts
Action: Daily summary email
```

**Setup:** Use Cloud Monitoring in Console or Terraform:
https://console.firebase.google.com/project/sierra-painting-prod/monitoring

---

## Phase 5: Monitor Initial Traffic (24 Hours)

### First Hour

**Check every 15 minutes:**
- [ ] Functions Console → Usage → Invocations (traffic flowing?)
- [ ] Functions Console → Logs → No ERROR entries
- [ ] Firestore → timeEntries collection (entries being created?)
- [ ] p95 latency < 600ms

**If any issue:**
1. Check logs for specific error
2. Apply fast fix from RUNBOOK.md
3. If unfixable in 30 minutes → Rollback (see Phase 6)

### First 24 Hours

**Check every 4 hours:**
- [ ] Error rate < 1% (excluding user-caused errors like geofence violations)
- [ ] p95 latency stable (< 600ms)
- [ ] No cold start spikes (minInstances keeping functions warm)
- [ ] Geofence exception rate reasonable (10-20%)
- [ ] Idempotent replay rate low (< 5%)
- [ ] No customer complaints about performance

**Dashboard:** https://console.firebase.google.com/project/sierra-painting-prod/functions/usage

---

## Phase 6: Rollback Procedure (If Needed)

### Option A: Redeploy Previous Version (Fast)

```bash
# Checkout previous tag
git checkout v0.9.0-last-stable

# Redeploy functions only (indexes stay)
firebase deploy --only functions --project sierra-painting-prod --force
```

**Time:** 3-5 minutes

### Option B: Roll Back Individual Function (Faster)

**Console Method:**
1. Navigate to: https://console.cloud.google.com/functions/list?project=sierra-painting-prod
2. Click on problematic function (e.g., clockIn)
3. Click "Revisions" tab
4. Select previous revision
5. Click "Rollback"

**Time:** 30 seconds

### Option C: Disable Problematic Function (Emergency)

```bash
# Delete function temporarily
firebase functions:delete clockIn --project sierra-painting-prod

# Client will fall back to error state
# Fix and redeploy when ready
```

**Time:** 10 seconds

---

## Phase 7: Production Readiness Checklist

### Performance ✅

- [ ] p95 latency < 600ms for hot callables
- [ ] No cold starts (minInstances: 1 active)
- [ ] Error rate < 1%
- [ ] All indexes ACTIVE

### Security ✅

- [ ] App Check enforced
- [ ] Immutability guards active (ensureMutable)
- [ ] Company scope isolation verified
- [ ] Audit trail working (approve, invoice, edit)

### Monitoring ✅

- [ ] All 6 alerts configured and active
- [ ] Log queries validated
- [ ] Metrics dashboard accessible
- [ ] On-call rotation defined

### Operations ✅

- [ ] RUNBOOK.md reviewed by ops team
- [ ] Rollback procedure tested
- [ ] Backfill normalizer run successfully
- [ ] Scheduled functions running (autoClockOut hourly)

---

## Phase 8: Canary Traffic Ramp (Optional - Advanced)

**If using Cloud Run traffic splitting:**

### 10% Canary

```bash
# Deploy canary revision
gcloud run services update-traffic clockin \
  --to-revisions=LATEST=10 \
  --region=us-east4 \
  --project=sierra-painting-prod
```

**Monitor for 1 hour:**
- Compare error rates between canary and stable
- Compare latency p95 between canary and stable
- If metrics match → Proceed to 50%

### 50% Canary

```bash
gcloud run services update-traffic clockin \
  --to-revisions=LATEST=50 \
  --region=us-east4 \
  --project=sierra-painting-prod
```

**Monitor for 4 hours:**
- Error rate stable?
- Latency stable?
- No customer complaints?
- If yes → Proceed to 100%

### 100% Production

```bash
gcloud run services update-traffic clockin \
  --to-revisions=LATEST=100 \
  --region=us-east4 \
  --project=sierra-painting-prod
```

**Note:** For MVP demo, you may skip canary ramp and go directly to 100%.

---

## Production Configuration

### Hot Callables

```typescript
{
  region: 'us-east4',
  minInstances: 1,
  concurrency: 20,
  timeoutSeconds: 10,
  memory: '256MiB',
}
```

**Applied to:**
- `clockIn`
- `clockOut`

**Cost:** ~$10/month per function = ~$20/month total

### Admin Callables

```typescript
{
  region: 'us-east4',
  memory: '256MiB',
}
```

**Applied to:**
- `bulkApproveTimeEntries`
- `createInvoiceFromTime`
- `editTimeEntry`
- `adminAutoClockOutOnce`
- `generateInvoice`
- `getInvoicePDFUrl`
- `regenerateInvoicePDF`
- `setUserRole`
- `manualCleanup`
- `getProbeMetrics`

**Cost:** Pay per invocation (no minInstances)

---

## Expected Production Metrics

### Performance

| Metric | Target | Acceptable | Alert |
|--------|--------|------------|-------|
| clockIn p95 | < 300ms | < 600ms | > 600ms |
| clockOut p95 | < 300ms | < 600ms | > 600ms |
| bulkApprove p95 | < 2s | < 5s | > 5s |
| createInvoice p95 | < 3s | < 5s | > 5s |
| Error rate | < 0.5% | < 1% | > 1% |

### Traffic

| Function | Expected Invocations/Day | Peak | Cost/Day |
|----------|--------------------------|------|----------|
| clockIn | 500 | 100/hour | $0.20 |
| clockOut | 500 | 100/hour | $0.20 |
| bulkApprove | 50 | 10/hour | $0.02 |
| createInvoice | 20 | 5/hour | $0.01 |

**Total Estimated Cost:** ~$15-20/day including minInstances

---

## Go-Live Communication

### Internal Team

**Email Template:**
```
Subject: Production Deployment - Time Tracking System v1.0.0

Team,

The time tracking system has been deployed to production:

Deployment Time: [timestamp]
Version: v1.0.0-demo
Status: GREEN

Key Features:
- Hot path optimization (p95 < 600ms)
- Bulk approve workflow (admin panel)
- Atomic invoice creation
- Exception tagging and triage

Monitoring Dashboard:
https://console.firebase.google.com/project/sierra-painting-prod/functions/usage

On-Call Contact: [name/phone]

Rollback Procedure: See PROD_CANARY_PLAN.md Phase 6

[Your Name]
```

### Customer Communication

**Only if customer-facing changes:**
- Mention improved performance (faster clock in/out)
- Highlight new admin features (bulk approve)
- Provide support contact for issues

---

## Success Criteria

**PRODUCTION: GO** when ALL of these are true:

- [x] All functions deployed successfully
- [x] All indexes ACTIVE
- [x] Backfill normalizer run (errors: 0)
- [x] Quick smoke tests pass (3 minimum)
- [x] p95 latency < 600ms
- [x] Zero ERROR logs in first hour
- [x] Monitoring alerts configured
- [x] RUNBOOK reviewed by ops
- [x] Rollback procedure tested

**Current Status:** 🟡 **Awaiting Staging Validation**

Once staging is GREEN, this plan can be executed in ~30 minutes.

---

**Prepared by:** Claude Code
**Date:** 2025-10-11
**Version:** v1.0.0-demo
