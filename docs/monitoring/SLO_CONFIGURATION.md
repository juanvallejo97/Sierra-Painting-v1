# SLO Monitoring & Alerting Configuration

**Version**: 1.0.0
**Last Updated**: 2025-10-11
**Owner**: Platform & SRE Team
**Status**: Active

---

## Table of Contents

1. [Overview](#overview)
2. [SLO Targets](#slo-targets)
3. [Alert Configuration](#alert-configuration)
4. [Dashboard Setup](#dashboard-setup)
5. [Incident Response](#incident-response)
6. [Query Reference](#query-reference)

---

## Overview

This document defines Service Level Objectives (SLOs), alerting policies, and dashboard configurations for the Sierra Painting platform. SLOs are monitored via:

1. **Latency Probes**: Scheduled function (`latencyProbe`) that runs every 5 minutes
2. **Performance Middleware**: Wraps Cloud Functions with automatic latency tracking
3. **Cloud Monitoring**: Google Cloud's native monitoring service
4. **Cloud Logging**: Structured logs for metrics and SLO breaches

---

## SLO Targets

### Cloud Functions (p95 Latency)

| Function | SLO Target (p95) | Slow Threshold (75% of SLO) | Breach Action |
|----------|------------------|----------------------------|---------------|
| `clockIn` | 1000ms | 750ms | Alert after 3 consecutive breaches |
| `clockOut` | 1000ms | 750ms | Alert after 3 consecutive breaches |
| `generateInvoice` | 2000ms | 1500ms | Alert after 2 consecutive breaches |
| `onInvoiceCreated` | 5000ms | 3750ms | Alert after 2 consecutive breaches |
| `getInvoicePDFUrl` | 500ms | 375ms | Alert after 5 consecutive breaches |
| `regenerateInvoicePDF` | 3000ms | 2250ms | Alert immediately |

### Firestore Operations

| Operation | SLO Target (p95) | Notes |
|-----------|------------------|-------|
| Single document read | 100ms | Baseline: 20-50ms |
| Single document write | 200ms | Baseline: 50-150ms |
| Batch write (10 docs) | 500ms | Baseline: 200-400ms |
| Query (1000 docs) | 1000ms | Baseline: 300-800ms |

### Cloud Storage Operations

| Operation | SLO Target (p95) | Notes |
|-----------|------------------|-------|
| Upload (small file <1MB) | 1000ms | Baseline: 300-700ms |
| Download (small file <1MB) | 500ms | Baseline: 100-300ms |
| Upload (large file >10MB) | 5000ms | Baseline: 2000-4000ms |
| Signed URL generation | 200ms | Baseline: 50-150ms |

### End-to-End Operations

| Operation | SLO Target (p95) | Notes |
|-----------|------------------|-------|
| Invoice generation (full flow) | 2000ms | Fetch entries + calc + create invoice |
| PDF generation (full flow) | 5000ms | Generate PDF + upload to Storage |
| Clock-in (with geofence check) | 1500ms | Includes location validation |

### Error Rate SLOs

| Metric | SLO Target | Breach Action |
|--------|------------|---------------|
| Overall error rate | <1% | Alert if >1% over 5 minutes |
| Authentication errors | <0.5% | Alert if >0.5% over 5 minutes |
| Permission denied errors | <0.1% | Alert if >0.1% over 5 minutes |
| PDF generation errors | <2% | Alert if >2% over 15 minutes |

---

## Alert Configuration

### 1. Cloud Monitoring Alert Policies

**Setup via Google Cloud Console**:
1. Navigate to: Cloud Console → Monitoring → Alerting → Create Policy
2. Use the configurations below

#### Alert Policy: High Latency (p95 Breach)

**Condition**:
```yaml
Metric: cloud_function/latency
Resource Type: cloud_function
Filter:
  - function_name: [clockIn, clockOut, generateInvoice]
  - percentile: 95
Threshold: > 2000ms
Duration: 5 minutes
```

**Notification Channels**:
- Email: ops-team@example.com
- Slack: #alerts-production
- PagerDuty: P2 (Business Hours)

**Documentation**:
```markdown
## High Latency Detected

**Impact**: Users may experience slow response times.

**Immediate Actions**:
1. Check Cloud Functions logs for errors
2. Check Firestore dashboard for quota issues
3. Check Cloud Storage for outages
4. Review recent deployments

**Runbook**: https://docs.example.com/runbooks/high-latency
```

#### Alert Policy: High Error Rate

**Condition**:
```yaml
Metric: cloud_function/error_count
Resource Type: cloud_function
Filter:
  - function_name: [all]
  - status: error
Aggregation: Rate (errors per minute)
Threshold: > 10 errors/min
Duration: 5 minutes
```

**Notification Channels**:
- Email: ops-team@example.com
- Slack: #alerts-production
- PagerDuty: P1 (24/7)

**Documentation**:
```markdown
## High Error Rate Detected

**Impact**: Users may be unable to complete actions.

**Immediate Actions**:
1. Check Cloud Functions logs for error details
2. Check recent deployments (rollback if needed)
3. Check Firebase status page for outages
4. Check authentication service status

**Runbook**: https://docs.example.com/runbooks/high-error-rate
```

#### Alert Policy: SLO Breach (Latency Probe)

**Condition**:
```yaml
Metric: logging.googleapis.com/user/latency_probe_breach
Resource Type: cloud_function
Filter:
  - function_name: latencyProbe
  - breach: true
Threshold: >= 3 breaches in 15 minutes
```

**Notification Channels**:
- Email: ops-team@example.com
- Slack: #alerts-production

**Documentation**:
```markdown
## Multiple SLO Breaches Detected

**Impact**: System performance degraded across multiple operations.

**Immediate Actions**:
1. Check latency probe logs for details
2. Check Google Cloud Status Dashboard
3. Check Firestore dashboard for issues
4. Check Cloud Storage dashboard for issues
5. Review recent deployments

**Runbook**: https://docs.example.com/runbooks/slo-breach
```

### 2. Log-Based Metrics

**Setup via gcloud CLI**:

```bash
# Create log-based metric for SLO breaches
gcloud logging metrics create slo_breach_count \
  --description="Count of SLO breaches" \
  --log-filter='
    resource.type="cloud_function"
    jsonPayload.breach=true
  '

# Create log-based metric for slow functions
gcloud logging metrics create slow_function_count \
  --description="Count of slow function executions" \
  --log-filter='
    resource.type="cloud_function"
    jsonPayload.durationMs>2000
  '

# Create log-based metric for PDF generation failures
gcloud logging metrics create pdf_generation_failure_count \
  --description="Count of PDF generation failures" \
  --log-filter='
    resource.type="cloud_function"
    resource.labels.function_name="onInvoiceCreated"
    severity="ERROR"
  '
```

### 3. Uptime Checks

**Setup via Google Cloud Console**:
1. Navigate to: Cloud Console → Monitoring → Uptime Checks → Create Check

**Check Configuration**:
```yaml
Name: Sierra Painting - Invoice PDF URL
Check Type: HTTPS
Resource Type: URL
Target:
  - Protocol: HTTPS
  - Host: us-east4-YOUR-PROJECT.cloudfunctions.net
  - Path: /getInvoicePDFUrl
Frequency: 5 minutes
Timeout: 10 seconds
Locations: Multiple (auto-selected)

Expected Response:
  - Status Code: 401 (unauthenticated - expected for health check)
  - Content: "unauthenticated"
```

---

## Dashboard Setup

### 1. Cloud Functions Performance Dashboard

**Create via Cloud Console**: Monitoring → Dashboards → Create Dashboard

**Widgets**:

1. **Function Latency (p95)**
   - Chart Type: Line Chart
   - Metric: `cloud_function/latency`
   - Aggregation: 95th percentile
   - Group By: `function_name`
   - Time Range: Last 6 hours

2. **Function Invocation Count**
   - Chart Type: Line Chart
   - Metric: `cloud_function/execution_count`
   - Aggregation: Sum
   - Group By: `function_name`
   - Time Range: Last 6 hours

3. **Function Error Rate**
   - Chart Type: Line Chart
   - Metric: `cloud_function/error_count`
   - Aggregation: Rate (errors per minute)
   - Group By: `function_name`
   - Time Range: Last 6 hours

4. **Function Execution Time Distribution**
   - Chart Type: Heatmap
   - Metric: `cloud_function/latency`
   - Group By: `function_name`
   - Time Range: Last 24 hours

### 2. Latency Probe Dashboard

**Widgets**:

1. **Probe Success Rate**
   - Chart Type: Scorecard
   - Metric: Custom (from logs)
   - Query: `jsonPayload.operation="latency_probe" AND jsonPayload.success=true`
   - Aggregation: Success % over last hour

2. **Probe Latency by Operation**
   - Chart Type: Bar Chart
   - Metric: Custom (from logs)
   - Query: `jsonPayload.operation=~"firestore_.*|storage_.*"`
   - Group By: `jsonPayload.operation`
   - Value: `jsonPayload.latencyMs`

3. **SLO Breach Timeline**
   - Chart Type: Timeline
   - Metric: Custom (from logs)
   - Query: `jsonPayload.breach=true`
   - Group By: `jsonPayload.operation`

### 3. Business Metrics Dashboard

**Widgets**:

1. **Invoice Generation Latency**
   - Chart Type: Line Chart
   - Metric: `cloud_function/latency`
   - Filter: `function_name="generateInvoice"`
   - Aggregation: 50th, 95th, 99th percentile

2. **PDF Generation Success Rate**
   - Chart Type: Scorecard
   - Metric: Custom (from Firestore)
   - Query: Invoices with `pdfPath != null` vs `pdfError != null`

3. **Clock-In/Clock-Out Latency**
   - Chart Type: Line Chart
   - Metric: `cloud_function/latency`
   - Filter: `function_name IN ("clockIn", "clockOut")`
   - Aggregation: 95th percentile

---

## Incident Response

### Severity Levels

| Severity | Definition | Response Time | Example |
|----------|------------|---------------|---------|
| P0 | Complete outage | 15 minutes | All functions failing |
| P1 | Major degradation | 1 hour | Invoice generation failing |
| P2 | Minor degradation | 4 hours | Slow PDF generation |
| P3 | Non-urgent | Next business day | Single function slow |

### Response Workflow

#### 1. Alert Received

1. **Acknowledge** the alert in PagerDuty/Slack
2. **Check dashboard** for scope of impact
3. **Review logs** for error details
4. **Assess severity** using table above

#### 2. Investigation

1. **Check Cloud Status**:
   - https://status.firebase.com
   - https://status.cloud.google.com

2. **Check Recent Deployments**:
   ```bash
   gcloud functions list --region=us-east4 --sort-by=updateTime
   ```

3. **Check Function Logs**:
   ```bash
   gcloud functions logs read FUNCTION_NAME --region=us-east4 --limit=50
   ```

4. **Check Firestore Metrics**:
   - Cloud Console → Firestore → Usage

5. **Check Storage Metrics**:
   - Cloud Console → Storage → Browser

#### 3. Mitigation

**If recent deployment caused issue**:
```bash
# Rollback function
gcloud functions deploy FUNCTION_NAME \
  --region=us-east4 \
  --source=gs://PATH_TO_PREVIOUS_VERSION

# Or delete function and redeploy
firebase deploy --only functions:FUNCTION_NAME
```

**If infrastructure issue**:
- Contact Google Cloud Support
- Check #firebase-support in Slack
- Tweet @GoogleCloud with issue details

**If quota issue**:
```bash
# Check quotas
gcloud compute project-info describe --project=YOUR_PROJECT

# Request quota increase
# Cloud Console → IAM & Admin → Quotas → Request Increase
```

#### 4. Communication

**Internal (Slack #incidents)**:
```
🚨 INCIDENT: Invoice generation high latency (P2)
Started: 2025-10-11 14:30 UTC
Status: Investigating
Impact: Invoices taking >5s to generate (SLO: 2s)
Updates: Every 15 minutes
```

**External (Status Page)**:
```
Investigating: We are currently investigating reports of slow invoice generation.
Customers may experience delays when creating invoices.
We will provide an update within 30 minutes.
```

#### 5. Resolution & Postmortem

**Resolution Message**:
```
✅ RESOLVED: Invoice generation high latency
Started: 2025-10-11 14:30 UTC
Resolved: 2025-10-11 15:15 UTC
Root Cause: Firestore query performance degradation
Fix: Optimized query with composite index
Impact: ~50 customers experienced 3-5s delays
Postmortem: Will be published within 48 hours
```

**Postmortem Template** (docs/postmortems/YYYY-MM-DD-incident-name.md):
```markdown
# Incident Postmortem: Invoice Generation High Latency

**Date**: 2025-10-11
**Duration**: 45 minutes
**Severity**: P2
**Impact**: ~50 customers

## Summary
[Brief description of incident]

## Timeline
[Chronological list of events]

## Root Cause
[Technical explanation of what caused the issue]

## Resolution
[What was done to fix the issue]

## Lessons Learned
[What went well, what didn't]

## Action Items
- [ ] Add missing index (Owner: @engineer, Due: 2025-10-15)
- [ ] Update monitoring query (Owner: @sre, Due: 2025-10-13)
- [ ] Document runbook (Owner: @lead, Due: 2025-10-18)
```

---

## Query Reference

### Cloud Logging Queries

**All SLO breaches in last hour**:
```
resource.type="cloud_function"
jsonPayload.breach=true
timestamp>="2025-10-11T14:00:00Z"
```

**Function latency by percentile**:
```
resource.type="cloud_function"
jsonPayload.durationMs>0
| summarize percentiles(jsonPayload.durationMs, [50, 95, 99]) by resource.labels.function_name
```

**Error rate by function**:
```
resource.type="cloud_function"
severity="ERROR"
| count by resource.labels.function_name
```

**Slow PDF generation**:
```
resource.type="cloud_function"
resource.labels.function_name="onInvoiceCreated"
jsonPayload.durationMs>3000
```

### Firestore Queries (for dashboards)

**Invoices with PDF generation failures**:
```typescript
db.collection('invoices')
  .where('pdfError', '!=', null)
  .orderBy('pdfErrorAt', 'desc')
  .limit(50);
```

**Average invoice generation time (last 100 invoices)**:
```typescript
// Use Cloud Function logs instead
// Query for "performance_metric" logs with functionName="generateInvoice"
```

### Cloud Monitoring Queries (MQL)

**p95 latency by function**:
```
fetch cloud_function
| metric 'cloudfunctions.googleapis.com/function/execution_times'
| group_by 1m, [value_execution_times_percentile: percentile(value.execution_times, 95)]
| every 1m
```

**Error rate by function**:
```
fetch cloud_function
| metric 'cloudfunctions.googleapis.com/function/execution_count'
| filter (resource.status == 'error')
| group_by 1m, [value_count: sum(value.count)]
| every 1m
```

---

## Maintenance

### Weekly Tasks

- [ ] Review alert fatigue (too many false positives?)
- [ ] Check SLO compliance (are we meeting targets?)
- [ ] Review slow query logs
- [ ] Update runbooks based on recent incidents

### Monthly Tasks

- [ ] Review and adjust SLO targets
- [ ] Audit alert policies (add/remove/modify)
- [ ] Update dashboards with new metrics
- [ ] Review postmortems and action items

### Quarterly Tasks

- [ ] Comprehensive SLO review with stakeholders
- [ ] Benchmark against industry standards
- [ ] Capacity planning based on growth trends
- [ ] Security audit of monitoring access

---

## Related Documentation

- [Performance Middleware](../../functions/src/monitoring/performance_middleware.ts)
- [Latency Probe](../../functions/src/monitoring/latency_probe.ts)
- [Cloud Monitoring Documentation](https://cloud.google.com/monitoring/docs)
- [Firebase Performance Monitoring](https://firebase.google.com/docs/perf-mon)
- [Incident Response Playbook](../ops/incident_response.md)

---

## Feedback

For questions or suggestions:
- Slack: #platform-team or #sre
- Email: sre@example.com
- GitHub Issues: tag `monitoring` and `slo`
