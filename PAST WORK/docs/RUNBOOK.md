# Operations Runbook - D'Sierra Painting

## Overview

This runbook covers operational procedures for monitoring, debugging, and responding to incidents in the D'Sierra Painting time tracking system.

## Quick Links

- **Staging Console:** https://console.firebase.google.com/project/sierra-staging
- **Production Console:** https://console.firebase.google.com/project/sierra-painting
- **Logs:** Functions → Logs tab OR `firebase functions:log --project <project>`
- **Firestore:** Firestore Database tab
- **Monitoring:** Functions → Dashboard (metrics, health)

---

## Health Checks

### Daily Smoke Test (2 minutes)

```bash
# 1. Check function health
firebase functions:list --project sierra-staging

# 2. Tail logs for errors
firebase functions:log --project sierra-staging --limit 50 | grep -i error

# 3. Test clock-in (via Functions Console or integration test)
# Functions Console → clockIn → Test with:
{
  "jobId": "<active-job-id>",
  "lat": 37.7793,
  "lng": -122.4193,
  "accuracy": 10.0,
  "clientEventId": "health-check-001",
  "deviceId": "health-check-device"
}

# Expected: {ok: true, id: "<entry-id>"} in ≤2s
```

### Metrics to Watch

**Latency (p95):**
- `clockIn` / `clockOut`: ≤ 600ms (target: ≤ 300ms)
- `bulkApproveTimeEntries`: ≤ 2s for 50 entries
- `generateInvoice`: ≤ 3s

**Error Rate:**
- Errors/minute: ≤ 1 (excluding user-caused errors like geofence violations)
- `FAILED_PRECONDITION` from missing indexes: 0

**Auto-Clockout:**
- Processed count: Usually 0-5 per run
- Runs every hour (check logs for `runAutoClockOutOnce: Complete`)

---

## Alerts Configuration

### Critical Alerts (Page immediately)

**1. High Error Rate**
```
Metric: cloud.googleapis.com/functions/execution/error_count
Condition: Rate > 5 errors/minute for 5 minutes
Threshold: Immediate alert
Action: Check logs, investigate root cause
```

**2. Function Timeout Spike**
```
Metric: cloud.googleapis.com/functions/execution/times
Condition: p95 > 10s for 5 minutes
Threshold: Immediate alert
Action: Check for cold starts, database slow queries
```

**3. Auto-Clockout Failure**
```
Log Query: severity=ERROR AND "runAutoClockOutOnce"
Condition: Any ERROR logs
Threshold: Immediate alert
Action: Run manual dry-run, check indexes
```

### Warning Alerts (Review daily)

**4. Elevated Latency**
```
Metric: cloud.googleapis.com/functions/execution/times
Condition: p95 > 600ms for clockIn/clockOut
Threshold: Daily summary
Action: Review function concurrency, cold start frequency
```

**5. Geofence Exception Rate**
```
Log Query: "Outside geofence" OR "GPS accuracy too low"
Condition: > 20% of clock attempts
Threshold: Daily summary
Action: Review geofence radius settings, check for GPS issues
```

**6. Idempotent Replay Rate**
```
Log Query: "Idempotent replay detected"
Condition: > 5% of clock attempts
Threshold: Daily summary
Action: Check client-side retry logic, network stability
```

---

## Common Issues & Fixes

### Issue: Clock-In Failing with "Missing Index"

**Symptoms:**
```
Error: FAILED_PRECONDITION: The query requires an index
```

**Diagnosis:**
```bash
# Check Firestore indexes status
firebase firestore:indexes --project sierra-staging

# Look for indexes in "CREATING" state
```

**Fix:**
```bash
# Deploy missing indexes
firebase deploy --only firestore:indexes --project sierra-staging

# Wait 5-15 minutes for index build
# Monitor: Firestore Console → Indexes tab
```

**Prevention:**
- Always deploy indexes before functions that use them
- Add index definitions to `firestore.indexes.json`
- Test queries against emulator before deploying

---

### Issue: Auto-Clockout Not Processing Entries

**Symptoms:**
- Scheduler runs but `processed: 0` in logs
- Workers report shifts > 12 hours not auto-closed

**Diagnosis:**
```bash
# Check scheduler logs
firebase functions:log --project sierra-staging \
  --only autoClockOut --limit 20

# Look for:
# - "No open entries found" (expected if no long shifts)
# - "Dry-run mode: no changes committed" (if testing)
# - Index errors
```

**Manual Trigger (Dry-Run):**
```javascript
// Functions Console → adminAutoClockOutOnce → Test
{
  "dryRun": true
}

// Expected response:
{
  "success": true,
  "processed": 2,
  "entries": [
    {"entryId": "...", "userId": "...", "duration": "15h"}
  ],
  "dryRun": true
}
```

**Fix:**
```bash
# If dry-run shows entries but real run doesn't process:
# 1. Check scheduler is enabled
firebase functions:config:get --project sierra-staging

# 2. Run manual trigger (not dry-run)
# Functions Console → adminAutoClockOutOnce → Test
{
  "dryRun": false
}

# 3. Verify entries are updated in Firestore
```

**Prevention:**
- Monitor auto-clockout logs hourly
- Alert if `processed: 0` for > 3 hours during work hours
- Test dry-run weekly

---

### Issue: Bulk Approve Failing

**Symptoms:**
```
Error: failed-precondition: Entry already invoiced
```

**Diagnosis:**
```bash
# Check entry status in Firestore
# Look for: approved: true, invoiceId: "..."
```

**Fix:**
- Entries already invoiced cannot be re-approved
- If invoice was created in error, delete invoice first, then re-approve
- Use `ensureMutable()` guard to prevent accidental mutations

**Prevention:**
- Show "Invoiced" badge in UI to prevent selection
- Filter out invoiced entries from Exceptions tab queries

---

### Issue: High Geofence Failure Rate

**Symptoms:**
- > 20% of clock attempts fail with geofence errors
- Worker complaints about location accuracy

**Diagnosis:**
```bash
# Query geofence failures
firebase functions:log --project sierra-staging --limit 100 | \
  grep "Outside geofence"

# Look for patterns:
# - Specific job IDs with high failure rate
# - Specific worker IDs (device GPS issues)
# - Time of day (indoor vs outdoor)
```

**Fix:**
```bash
# Temporary: Increase geofence radius for problematic job
# Firestore → jobs/<job-id> → radiusM: 150 (was 100)

# Long-term:
# - Review job site coordinates (verify accuracy)
# - Consider adaptive radius based on accuracy
# - Add "I'm here" button for manual override (requires admin approval)
```

**Prevention:**
- Set realistic geofence radii (100-250m for typical job sites)
- Test geofence at each job site before assigning workers
- Monitor accuracy distribution in logs

---

## Log Queries

### Find All Idempotent Replays (Last 24h)

```bash
firebase functions:log --project sierra-staging --limit 1000 | \
  grep "Idempotent replay detected"
```

**Expected:** Low rate (< 5% of requests)
**High rate indicates:** Client retry loops or network instability

---

### Find All Geofence Violations (Last Hour)

```bash
firebase functions:log --project sierra-staging --limit 500 | \
  grep -E "(Outside geofence|GPS accuracy too low)"
```

**Expected:** Varies by job site, typically 10-20% of attempts
**High rate indicates:** Radius too small or GPS issues

---

### Find All Auto-Clockout Events (Last Week)

```bash
firebase functions:log --project sierra-staging --limit 5000 | \
  grep "runAutoClockOutOnce: Complete"
```

**Expected:** Hourly runs, 0-5 processed per run
**High count indicates:** Workers forgetting to clock out

---

### Find All Failed Approvals

```bash
firebase functions:log --project sierra-staging --limit 500 | \
  grep -E "(bulkApproveTimeEntries.*failed|Entry belongs to different company)"
```

**Expected:** Zero (all approvals should succeed)
**Any failures indicate:** Permission issues or data corruption

---

## Rollback Procedures

### Rollback Functions to Previous Version

```bash
# List recent deployments
firebase functions:log --project sierra-staging --limit 10 | \
  grep "Function deployment"

# Revert to previous version (Cloud Console)
# 1. Cloud Functions Console → Select function
# 2. Click "Revisions" tab
# 3. Select previous revision → "Rollback"

# OR redeploy from git
git checkout <previous-commit>
npm --prefix functions run build
firebase deploy --only functions --project sierra-staging
```

### Disable Auto-Clockout (Emergency)

```bash
# Delete scheduler function temporarily
firebase functions:delete autoClockOut --project sierra-staging

# Re-enable later
firebase deploy --only functions:autoClockOut --project sierra-staging
```

### Disable App Check (Emergency - Security Risk)

```javascript
// In firebase.json, temporarily remove appCheckToken enforcement
// ONLY use if App Check is blocking legitimate traffic

// Redeploy functions
firebase deploy --only functions --project sierra-staging

// Re-enable ASAP after fix
```

---

## Performance Optimization

### Cold Start Mitigation

**Issue:** First request after idle takes 3-5s

**Fix:** Use `minInstances: 1` for hot paths
```typescript
// In functions/src/index.ts
export const clockIn = onCall(
  { region: 'us-east4', minInstances: 1 },  // Keep 1 instance warm
  async (request) => { /* ... */ }
);
```

**Cost:** ~$5/month per instance for always-on

---

### Query Optimization

**Issue:** `getTimeEntries` slow for large datasets

**Fix:** Always use pagination
```dart
// Client code
final firstPage = await repo.getTimeEntries(
  userId: userId,
  limit: 50,  // Always specify limit
);

// Next page
final nextPage = await repo.getTimeEntries(
  userId: userId,
  limit: 50,
  startAfterDoc: firstPage.lastDocument,  // Cursor-based pagination
);
```

---

## Backup & Recovery

### Automated Backups

Firestore backups run daily at 2 AM UTC via Cloud Scheduler.

**Verify:**
```bash
gcloud firestore operations list --project sierra-staging
```

**Restore from backup:**
```bash
# List backups
gcloud firestore backups list --project sierra-staging

# Restore to new database
gcloud firestore databases restore \
  --source-backup=<backup-name> \
  --destination-database=<new-db-name> \
  --project=sierra-staging
```

---

## Staging Smoke Test (5 minutes)

```bash
# 1. Seed test data
npm run seed:staging

# 2. Worker flow: Clock In
# Functions Console → clockIn → Test
{
  "jobId": "<seeded-job-id>",
  "lat": 37.7793,
  "lng": -122.4193,
  "accuracy": 10.0,
  "clientEventId": "smoke-001",
  "deviceId": "smoke-device"
}
# Expected: {ok: true, id: "<entry-id>"} in ≤2s

# 3. Admin flow: Bulk Approve
# Functions Console → bulkApproveTimeEntries → Test
{
  "entryIds": ["<entry-id-from-step-2>"]
}
# Expected: {approved: 1, failed: 0}

# 4. Invoice flow: Create from Time
# Functions Console → generateInvoice → Test
{
  "companyId": "<company-id>",
  "customerId": "<customer-id>",
  "timeEntryIds": ["<entry-id>"],
  "dueDate": "2025-11-10"
}
# Expected: {ok: true, invoiceId: "<invoice-id>"}

# 5. Auto-clockout: Dry-Run
# Functions Console → adminAutoClockOutOnce → Test
{
  "dryRun": true
}
# Expected: {success: true, processed: N}

# 6. Verify logs are clean
firebase functions:log --project sierra-staging --limit 50 | grep ERROR
# Expected: No errors (or only expected test errors)
```

---

## On-Call Escalation

### Severity 1 (Critical - Page Immediately)

- Functions completely down (all requests failing)
- Data loss or corruption detected
- Security breach detected

**Actions:**
1. Page on-call engineer immediately
2. Check Cloud Status: https://status.cloud.google.com
3. Rollback if recent deployment
4. Engage Firebase support if infrastructure issue

---

### Severity 2 (High - Respond within 1 hour)

- High error rate (> 10% of requests)
- Latency spike (p95 > 5s)
- Auto-clockout failing for > 3 hours

**Actions:**
1. Review logs for root cause
2. Apply temporary mitigations (increase limits, disable features)
3. Deploy fix within 4 hours

---

### Severity 3 (Medium - Respond next business day)

- Elevated geofence failure rate
- Slow queries (p95 > 1s but < 5s)
- Minor UI issues

**Actions:**
1. File bug with detailed logs
2. Schedule fix in next sprint
3. Document workaround for users

---

## Contacts

- **On-Call Engineer:** [Insert phone/Slack]
- **Firebase Support:** https://firebase.google.com/support
- **Product Owner:** [Insert contact]
