# Monitoring & Alerting Guide

> **Purpose**: Comprehensive guide for monitoring Sierra Painting deployments and responding to issues
>
> **Last Updated**: 2024
>
> **Related Documentation**: See [observability.md](./observability.md) for logging details

---

## Overview

This guide covers monitoring, alerting, and observability for Sierra Painting's staging and production environments.

**Key Monitoring Areas:**
- Cloud Functions performance and errors
- Firebase services (Auth, Firestore, Storage)
- Mobile app crashes and performance
- User experience metrics
- Security and abuse detection

---

## Monitoring Dashboards

### Firebase Console

#### Staging Environment
- **Console**: https://console.firebase.google.com/project/sierra-painting-staging/overview
- **Functions**: https://console.firebase.google.com/project/sierra-painting-staging/functions
- **Firestore**: https://console.firebase.google.com/project/sierra-painting-staging/firestore
- **Authentication**: https://console.firebase.google.com/project/sierra-painting-staging/authentication
- **Storage**: https://console.firebase.google.com/project/sierra-painting-staging/storage

#### Production Environment
- **Console**: https://console.firebase.google.com/project/sierra-painting-prod/overview
- **Functions**: https://console.firebase.google.com/project/sierra-painting-prod/functions
- **Firestore**: https://console.firebase.google.com/project/sierra-painting-prod/firestore
- **Authentication**: https://console.firebase.google.com/project/sierra-painting-prod/authentication
- **Storage**: https://console.firebase.google.com/project/sierra-painting-prod/storage

### Google Cloud Console

#### Staging
- **Cloud Functions Logs**: https://console.cloud.google.com/logs/query?project=sierra-painting-staging
- **Error Reporting**: https://console.cloud.google.com/errors?project=sierra-painting-staging
- **Metrics Explorer**: https://console.cloud.google.com/monitoring/metrics-explorer?project=sierra-painting-staging
- **Trace**: https://console.cloud.google.com/traces?project=sierra-painting-staging

#### Production
- **Cloud Functions Logs**: https://console.cloud.google.com/logs/query?project=sierra-painting-prod
- **Error Reporting**: https://console.cloud.google.com/errors?project=sierra-painting-prod
- **Metrics Explorer**: https://console.cloud.google.com/monitoring/metrics-explorer?project=sierra-painting-prod
- **Trace**: https://console.cloud.google.com/traces?project=sierra-painting-prod

### Mobile App Monitoring

#### Crashlytics
- **Staging**: https://console.firebase.google.com/project/sierra-painting-staging/crashlytics
- **Production**: https://console.firebase.google.com/project/sierra-painting-prod/crashlytics

#### Performance Monitoring
- **Staging**: https://console.firebase.google.com/project/sierra-painting-staging/performance
- **Production**: https://console.firebase.google.com/project/sierra-painting-prod/performance

---

## Key Metrics & Thresholds

### Cloud Functions

#### Performance Metrics

| Metric | Threshold (Staging) | Threshold (Production) | Action if Exceeded |
|--------|---------------------|------------------------|-------------------|
| P95 Latency | < 3s | < 2s | Investigate slow queries, optimize code |
| Error Rate | < 5% | < 1% | Check logs, consider rollback |
| Cold Start Time | < 5s | < 5s | Review function initialization |
| Invocations/min | Monitor | Monitor | Scale if needed |
| Memory Usage | < 512MB | < 512MB | Optimize memory usage |

#### Error Rate Thresholds

```
🟢 Green:  Error rate < 1%     → Normal operation
🟡 Yellow: Error rate 1-5%     → Monitor closely, investigate
🔴 Red:    Error rate > 5%     → Consider rollback or hotfix
⚫ Black:  Error rate > 20%    → Immediate rollback required
```

### Firestore

| Metric | Threshold | Action if Exceeded |
|--------|-----------|-------------------|
| Document Reads/min | Monitor baseline | Optimize queries, add caching |
| Document Writes/min | Monitor baseline | Batch writes, optimize logic |
| Query Latency P95 | < 500ms | Add indexes, optimize queries |
| Rule Denials | < 1% of requests | Review security rules |

### Mobile App

| Metric | Threshold | Action if Exceeded |
|--------|-----------|-------------------|
| Crash-free users | > 99% | Investigate crashes in Crashlytics |
| ANR Rate | < 0.5% | Optimize UI thread, async operations |
| App Start Time | < 3s | Optimize initialization |
| Screen Render Time | < 16ms (60fps) | Optimize UI, reduce complexity |

---

## Alert Channels

### Immediate Alerts (Critical Issues)

**Criteria:**
- Error rate > 20%
- Crash-free users < 95%
- Production deployment failures
- Security rule violations spike

**Channels:**
- PagerDuty (if configured)
- Slack: #sierra-painting-alerts
- Email: oncall@example.com

### Warning Alerts (Monitor Closely)

**Criteria:**
- Error rate 5-20%
- P95 latency > threshold
- Unusual traffic patterns
- Failed deployments to staging

**Channels:**
- Slack: #sierra-painting-alerts
- Email: dev-team@example.com

### Info Alerts (Good to Know)

**Criteria:**
- Successful deployments
- Weekly metric summaries
- Capacity warnings (approaching limits)

**Channels:**
- Slack: #sierra-painting-deployments
- Email: dev-team@example.com

---

## Monitoring Queries

### Cloud Logging Queries

#### All Function Errors (Last Hour)
```
resource.type="cloud_function"
severity>=ERROR
timestamp>="2024-01-01T00:00:00Z"
```

#### Slow Function Executions (>2s)
```
resource.type="cloud_function"
jsonPayload.latencyMs>2000
timestamp>="2024-01-01T00:00:00Z"
```

#### Authentication Failures
```
resource.type="cloud_function"
jsonPayload.message=~"auth.*failed"
OR jsonPayload.message=~"unauthorized"
timestamp>="2024-01-01T00:00:00Z"
```

#### Payment Processing Errors
```
resource.type="cloud_function"
jsonPayload.message=~"payment.*error"
OR jsonPayload.message=~"stripe.*failed"
severity>=ERROR
timestamp>="2024-01-01T00:00:00Z"
```

### Metrics Explorer Queries

#### Function Invocation Rate
```
Metric: cloud.googleapis.com/functions/execution_count
Resource: cloud_function
Aggregation: rate (1 minute)
```

#### Function Error Rate
```
Metric: cloud.googleapis.com/functions/execution_count
Filter: status != "ok"
Aggregation: rate (1 minute)
```

#### Function Execution Time (P95)
```
Metric: cloud.googleapis.com/functions/execution_times
Aggregation: 95th percentile
```

---

## Post-Deployment Monitoring

### First 15 Minutes (Critical)

**Actions:**
- [ ] Check Error Reporting for new errors
- [ ] Monitor function invocation count (should match baseline)
- [ ] Check Crashlytics for new crashes
- [ ] Verify no authentication issues
- [ ] Monitor P95 latency

**Queries to Run:**
```bash
# Check recent errors
gcloud logging read "resource.type=cloud_function severity>=ERROR" \
  --project=sierra-painting-prod \
  --limit=50 \
  --format=json

# Check function metrics
gcloud monitoring time-series list \
  --project=sierra-painting-prod \
  --filter='metric.type="cloudfunctions.googleapis.com/function/execution_count"' \
  --interval-start-time="2024-01-01T00:00:00Z"
```

### First Hour

**Actions:**
- [ ] Compare error rates to pre-deployment baseline
- [ ] Check user-reported issues (support channels)
- [ ] Monitor business metrics (successful operations)
- [ ] Review function cold start times

### First 24 Hours

**Actions:**
- [ ] Review daily metrics summary
- [ ] Check for any patterns in errors
- [ ] Monitor user feedback
- [ ] Document any issues encountered

---

## Alerting Setup (TODO)

### Cloud Monitoring Alert Policies

#### High Error Rate Alert
```yaml
# TODO: Implement via Terraform or Console
Name: "Cloud Functions High Error Rate"
Condition: error_rate > 0.05 for 5 minutes
Notification: Slack + Email
Severity: Critical
```

#### High Latency Alert
```yaml
# TODO: Implement via Terraform or Console
Name: "Cloud Functions High Latency"
Condition: P95 latency > 3s for 5 minutes
Notification: Slack
Severity: Warning
```

#### Crashlytics Alert
```yaml
# TODO: Configure in Firebase Console
Name: "High Crash Rate"
Condition: crash_free_users < 99% for 15 minutes
Notification: Slack + Email
Severity: Critical
```

---

## Incident Response

### Severity Levels

#### P0 - Critical (Production Down)
- **Response Time**: Immediate
- **Examples**: Complete service outage, data loss, security breach
- **Actions**: Page on-call, start incident response, consider immediate rollback

#### P1 - High (Major Impact)
- **Response Time**: < 15 minutes
- **Examples**: Error rate > 20%, crash rate > 5%, payment failures
- **Actions**: Alert team, investigate, prepare rollback plan

#### P2 - Medium (Degraded Service)
- **Response Time**: < 1 hour
- **Examples**: Error rate 5-20%, high latency, feature not working
- **Actions**: Create ticket, investigate, plan fix

#### P3 - Low (Minor Issue)
- **Response Time**: < 1 day
- **Examples**: Edge case errors, cosmetic issues, minor bugs
- **Actions**: Create ticket, prioritize in backlog

### Incident Response Checklist

1. **Detect & Alert**
   - [ ] Alert triggered or issue reported
   - [ ] Severity assessed
   - [ ] On-call engineer notified (if P0/P1)

2. **Investigate**
   - [ ] Check monitoring dashboards
   - [ ] Review recent deployments
   - [ ] Check error logs
   - [ ] Identify root cause

3. **Mitigate**
   - [ ] Implement immediate fix (hotfix/rollback)
   - [ ] Verify mitigation works
   - [ ] Monitor metrics return to normal

4. **Communicate**
   - [ ] Update status page (if applicable)
   - [ ] Notify stakeholders
   - [ ] Post incident summary

5. **Post-Mortem**
   - [ ] Document incident
   - [ ] Identify preventive measures
   - [ ] Update runbooks
   - [ ] Create follow-up tickets

---

## Useful Commands

### Check Recent Function Logs
```bash
# Staging
firebase functions:log --project sierra-painting-staging --limit 100

# Production
firebase functions:log --project sierra-painting-prod --limit 100
```

### Stream Live Logs
```bash
gcloud logging tail "resource.type=cloud_function" \
  --project=sierra-painting-prod \
  --format="table(timestamp,severity,jsonPayload.message)"
```

### Get Error Summary
```bash
gcloud logging read "resource.type=cloud_function severity>=ERROR" \
  --project=sierra-painting-prod \
  --limit=100 \
  --format=json | jq '.[] | {timestamp, function: .resource.labels.function_name, message: .jsonPayload.message}'
```

### Check Function Status
```bash
gcloud functions list --project=sierra-painting-prod
```

---

## Dashboard Setup Guide (TODO)

### Custom Dashboard Creation

1. **Navigate to Cloud Monitoring**
   - Open: https://console.cloud.google.com/monitoring
   - Select project: sierra-painting-prod

2. **Create Dashboard**
   - Click "Dashboards" → "Create Dashboard"
   - Name: "Sierra Painting - Production Overview"

3. **Add Charts**
   - Function Invocations (time series)
   - Error Rate (gauge)
   - P95 Latency (heatmap)
   - Active Users (counter)
   - Firestore Operations (stacked area)

4. **Share Dashboard**
   - Click "Share" → Get shareable link
   - Add to docs and team wiki

---

## Related Documentation

- [Observability Guide](./observability.md) - Logging and tracing
- [Rollout & Rollback Strategy](../rollout-rollback.md) - Deployment procedures
- [Rollback Procedures](../ui/ROLLBACK_PROCEDURES.md) - Emergency rollback steps
- [Deployment Checklist](../deployment_checklist.md) - Pre/post deployment tasks

---

## Notes

### Best Practices

- ✅ Check monitoring before and after each deployment
- ✅ Set up alerts before going to production
- ✅ Document baseline metrics for comparison
- ✅ Have rollback plan ready during deployments
- ✅ Monitor for 24 hours after major deployments

### Common Pitfalls

- ❌ Deploying without monitoring in place
- ❌ Ignoring warning signs (elevated error rates)
- ❌ Not having alert channels configured
- ❌ Forgetting to check staging metrics before prod
- ❌ Missing baseline metrics for comparison

### Future Improvements

- [ ] Implement automated alerting (Cloud Monitoring)
- [ ] Set up custom dashboards for each service
- [ ] Add business metrics tracking (successful operations)
- [ ] Implement SLO/SLI tracking
- [ ] Add capacity planning metrics
- [ ] Create runbooks for common issues

---

**Last Updated**: 2024  
**Review Schedule**: After each major deployment  
**Owner**: Engineering Team
