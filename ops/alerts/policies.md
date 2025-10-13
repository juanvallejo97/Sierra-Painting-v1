# Alerting Policies & Runbooks

**Version**: 1.0.0
**Last Updated**: 2025-10-11
**Owner**: Platform Team
**Status**: Active

---

## Table of Contents

1. [Overview](#overview)
2. [Alert Definitions](#alert-definitions)
3. [Severity Levels](#severity-levels)
4. [Escalation Procedures](#escalation-procedures)
5. [Runbooks](#runbooks)
6. [SLO Enforcement](#slo-enforcement)
7. [On-Call Procedures](#on-call-procedures)
8. [Notification Channels](#notification-channels)

---

## Overview

This document defines alerting policies, runbooks, and escalation procedures for the Sierra Painting timeclock system. All alerts are designed to be **actionable**, **specific**, and **tied to SLO violations** or critical system failures.

**Philosophy**: Alerts should wake someone up only when immediate action is required. For informational monitoring, use dashboards.

---

## Alert Definitions

### Critical Alerts (P0)

#### 1. High Error Rate

**Condition**: `rate(timeclock_errors[5m]) > 0.05` (>5% error rate)
**Duration**: 2 minutes
**Impact**: Workers cannot clock in/out, affecting payroll accuracy
**Channels**: PagerDuty, Slack (#incidents), Email
**Response Time**: < 15 minutes

**Description**: Error rate exceeds 5% over a 5-minute window. This indicates a systemic issue affecting multiple users.

**Runbook**: [High Error Rate Runbook](#runbook-high-error-rate)

---

#### 2. Firestore Unavailable

**Condition**: `firestore_health_check == 0`
**Duration**: 1 minute
**Impact**: Complete system outage
**Channels**: PagerDuty, Slack (#incidents), Email
**Response Time**: < 5 minutes

**Description**: Firestore health check failing. All operations will fail.

**Runbook**: [Firestore Outage Runbook](#runbook-firestore-outage)

---

#### 3. Auth Service Unavailable

**Condition**: `firebase_auth_health_check == 0`
**Duration**: 1 minute
**Impact**: Users cannot login
**Channels**: PagerDuty, Slack (#incidents), Email
**Response Time**: < 5 minutes

**Description**: Firebase Auth is down or unreachable.

**Runbook**: [Auth Outage Runbook](#runbook-auth-outage)

---

### Warning Alerts (P1)

#### 4. clockIn SLO Violation

**Condition**: `timeclock_clockIn_latency_p95 > 2000ms`
**Duration**: 5 minutes
**Impact**: Degraded user experience
**Channels**: Slack (#alerts), Email
**Response Time**: < 30 minutes

**Description**: 95th percentile latency for clockIn operations exceeds 2000ms SLO.

**Runbook**: [SLO Violation Runbook](#runbook-slo-violation)

---

#### 5. clockOut SLO Violation

**Condition**: `timeclock_clockOut_latency_p95 > 1500ms`
**Duration**: 5 minutes
**Impact**: Degraded user experience
**Channels**: Slack (#alerts), Email
**Response Time**: < 30 minutes

**Description**: 95th percentile latency for clockOut operations exceeds 1500ms SLO.

**Runbook**: [SLO Violation Runbook](#runbook-slo-violation)

---

#### 6. Low Success Rate

**Condition**: `success_rate < 95%` over 10 minutes
**Duration**: 10 minutes
**Impact**: Elevated failure rate
**Channels**: Slack (#alerts)
**Response Time**: < 1 hour

**Description**: Overall success rate drops below 95%.

**Runbook**: [Low Success Rate Runbook](#runbook-low-success-rate)

---

#### 7. High Geofence Violation Rate

**Condition**: `rate(timeclock_geofence_violations[10m]) > 0.2` (>20%)
**Duration**: 10 minutes
**Impact**: Workers may be attempting to clock in from wrong locations
**Channels**: Slack (#alerts)
**Response Time**: < 2 hours

**Description**: More than 20% of clock-in attempts are outside geofence.

**Runbook**: [Geofence Investigation Runbook](#runbook-geofence-violations)

---

### Informational Alerts (P2)

#### 8. Pending Entries Backlog

**Condition**: `count(timeEntries{status=pending}) > 100`
**Duration**: 30 minutes
**Impact**: Admin review queue is growing
**Channels**: Slack (#ops)
**Response Time**: Next business day

**Description**: More than 100 pending time entries awaiting admin review.

**Action**: Review admin capacity, check for automation issues.

---

#### 9. Firestore Document Count Alert

**Condition**: `count(firestore_documents) > 90% of quota`
**Duration**: 1 hour
**Impact**: Risk of hitting storage limits
**Channels**: Slack (#ops), Email
**Response Time**: Within 1 week

**Description**: Approaching Firestore document count limits.

**Action**: Review data retention policies, implement TTL for old documents.

---

## Severity Levels

| Level | Name | Response Time | Channels | Escalation |
|-------|------|---------------|----------|------------|
| P0 | Critical | < 15 min | PagerDuty, Slack, Email | Immediate |
| P1 | Warning | < 30 min | Slack, Email | If unresolved in 1h |
| P2 | Info | Next business day | Slack | None |

---

## Escalation Procedures

### P0 (Critical) Escalation

1. **0-15 min**: On-call engineer responds via PagerDuty
2. **15-30 min**: If unresolved, page team lead
3. **30-60 min**: If unresolved, page engineering manager
4. **60+ min**: Initiate incident response protocol, page CTO

### P1 (Warning) Escalation

1. **0-30 min**: On-call engineer acknowledges alert
2. **1 hour**: If unresolved, notify team lead via Slack
3. **2 hours**: If unresolved, page on-call engineer
4. **4 hours**: Escalate to P0 if impact worsens

### P2 (Info) Escalation

- No immediate escalation
- Review during next sprint planning
- Create Jira ticket for tracking

---

## Runbooks

### Runbook: High Error Rate

**Alert**: `rate(timeclock_errors[5m]) > 0.05`

**Symptoms**:
- Multiple users reporting clock-in/out failures
- Error rate dashboard spiking
- Slack reports from customer support

**Investigation Steps**:

1. **Check Firebase Status**:
   ```bash
   curl https://status.firebase.google.com/
   ```
   - If Firebase incident in progress, wait for resolution or implement workaround

2. **Check Recent Deployments**:
   ```bash
   firebase functions:list
   git log --oneline -10
   ```
   - If recent deployment (< 1 hour), consider rollback

3. **Check Function Logs**:
   ```bash
   firebase functions:log --only clockIn,clockOut --limit 50
   ```
   - Look for error patterns: geofence, auth, database

4. **Check Error Breakdown**:
   - Open dashboard: ops/dashboards/staging_timeclock_dashboard.json
   - Check "Error Types" pie chart
   - Identify dominant error type

**Common Causes & Fixes**:

| Error Type | Cause | Fix |
|------------|-------|-----|
| Geofence violations | GPS drift / Job geofence too small | Temporarily increase geofence radius |
| Auth errors | Token expiration / Claims not set | Verify custom claims via Firebase Console |
| Firestore errors | Rate limits / Index missing | Check quota, deploy missing indexes |
| Function timeout | Cold start / Heavy computation | Increase min instances or optimize code |

**Resolution**:
- Mark incident as resolved in PagerDuty
- Post-mortem within 48 hours (for P0)
- Update runbook with learnings

---

### Runbook: Firestore Outage

**Alert**: `firestore_health_check == 0`

**Symptoms**:
- All operations failing
- Firebase Console unreachable
- Health check endpoint returning 503

**Investigation Steps**:

1. **Check Firebase Status Page**:
   - Visit: https://status.firebase.google.com/
   - If incident posted, subscribe to updates

2. **Verify Project Configuration**:
   ```bash
   firebase projects:list
   firebase use staging
   ```

3. **Test Direct Firestore Access**:
   ```bash
   firebase firestore:indexes
   ```

**Actions**:

- **If Firebase Incident**: Wait for resolution, monitor status page
- **If Regional Outage**: Consider failover to backup region (if configured)
- **If Configuration Issue**: Verify `.firebaserc`, service account permissions

**Communication**:
- Post status update to #incidents Slack channel
- Update status page (if customer-facing)
- Notify customer support team

---

### Runbook: Auth Outage

**Alert**: `firebase_auth_health_check == 0`

**Symptoms**:
- Login failures
- "Unable to authenticate" errors
- Firebase Auth Console unreachable

**Investigation Steps**:

1. **Check Firebase Status**: https://status.firebase.google.com/
2. **Verify Auth Emulator** (if staging):
   ```bash
   curl http://localhost:9099
   ```
3. **Check Auth Configuration**:
   ```bash
   firebase auth:export users.json --project staging
   ```

**Actions**:
- If Firebase incident, wait for resolution
- If emulator issue, restart emulators
- If quota exceeded, upgrade plan or request increase

---

### Runbook: SLO Violation

**Alert**: `timeclock_clockIn_latency_p95 > 2000ms` OR `timeclock_clockOut_latency_p95 > 1500ms`

**Investigation Steps**:

1. **Check Dashboard**: Open staging_timeclock_dashboard.json
   - Review latency trends (last 6 hours)
   - Check operation volume (is load spiking?)

2. **Run Latency Probe**:
   ```bash
   cd tools/perf
   npx ts-node latency_probe.ts --env=staging --samples=10
   ```

3. **Check Function Performance**:
   ```bash
   firebase functions:log --only clockIn,clockOut --limit 20
   ```
   - Look for slow queries, cold starts, external API delays

4. **Check Firestore Indexes**:
   ```bash
   firebase firestore:indexes
   ```
   - Verify all indexes are `READY`

**Common Causes**:

| Cause | Symptom | Fix |
|-------|---------|-----|
| Cold Start | First request slow, then fast | Increase min instances to 1 |
| Missing Index | `index_not_found` error | Deploy missing index |
| High Load | Consistent high latency | Scale up function instances |
| External API | Geolocation API slow | Add timeout, implement caching |
| Large Document | Document >1MB | Refactor schema, denormalize |

**Temporary Mitigation**:
```bash
# Increase min instances
firebase functions:config:set clockin.min_instances=2
firebase deploy --only functions:clockIn
```

**Long-term Fix**:
- Optimize queries
- Add caching layer
- Denormalize data
- Implement pagination

---

### Runbook: Low Success Rate

**Alert**: `success_rate < 95%`

**Investigation**:
1. Check error breakdown dashboard
2. Identify top error types
3. Check if errors are user-driven (geofence violations) or systemic

**Actions**:
- If user-driven: Review job geofence configuration, worker assignments
- If systemic: Follow High Error Rate runbook

---

### Runbook: Geofence Violations

**Alert**: `rate(timeclock_geofence_violations[10m]) > 0.2`

**Investigation**:
1. Check which jobs have highest violation rates
2. Review job geofence radius settings
3. Check GPS accuracy of recent entries

**Potential Causes**:
- Geofence radius too small for job site
- Workers arriving before job site marked
- GPS drift in urban areas (tall buildings)
- Workers intentionally outside geofence

**Actions**:
- Review and adjust geofence radii for problematic jobs
- Educate workers on geofence requirements
- Consider "soft geofence" with admin override

---

## SLO Enforcement

### SLO Targets

| Metric | Target | Measurement Window | Consequences |
|--------|--------|-------------------|--------------|
| clockIn p95 latency | < 2000ms | 7-day rolling | Alert if violated 5 min |
| clockOut p95 latency | < 1500ms | 7-day rolling | Alert if violated 5 min |
| Success rate | > 95% | 7-day rolling | Alert if violated 10 min |
| Availability | > 99.5% | 30-day rolling | Incident review required |

### SLO Review Process

**Weekly**:
- Review SLO compliance dashboard
- Identify trends (improving/degrading)
- Update SLO targets if needed

**Monthly**:
- Generate SLO report for stakeholders
- Review incidents that caused SLO violations
- Plan improvements for next quarter

**Quarterly**:
- Reassess SLO targets based on business needs
- Update alerting thresholds
- Review runbooks for accuracy

---

## On-Call Procedures

### On-Call Schedule

- **Rotation**: Weekly, Monday 9am ET - Monday 9am ET
- **Primary**: Responds to all P0/P1 alerts
- **Secondary**: Backup for primary, responds if primary unavailable (15 min)
- **Manager**: Escalation point for P0 incidents >30 min

### On-Call Responsibilities

**During Shift**:
- Monitor PagerDuty for incoming alerts
- Acknowledge alerts within 5 minutes (P0) or 15 minutes (P1)
- Follow runbooks for investigation
- Escalate if unable to resolve within time limits
- Document all actions in incident ticket

**Handoff**:
- Review open incidents with next on-call
- Share context on ongoing investigations
- Update runbooks if new issues encountered

### Incident Response Protocol

1. **Acknowledge**: Acknowledge alert in PagerDuty
2. **Assess**: Determine severity and impact
3. **Communicate**: Post to #incidents Slack channel
4. **Investigate**: Follow runbook
5. **Mitigate**: Implement fix or workaround
6. **Resolve**: Mark incident resolved
7. **Document**: Write post-mortem (P0 only)

---

## Notification Channels

| Channel | Purpose | Recipients | Alert Levels |
|---------|---------|------------|--------------|
| **PagerDuty** | Critical alerts | On-call engineer | P0 |
| **Slack #incidents** | Critical incidents | Eng team, Leadership | P0 |
| **Slack #alerts** | Warning alerts | Eng team | P1 |
| **Slack #ops** | Informational | Platform team | P2 |
| **Email** | All alerts | On-call, Team lead | P0, P1 |

### Channel Setup

**PagerDuty**:
- Service: Sierra Painting Timeclock
- Escalation Policy: Primary (5 min) → Secondary (10 min) → Manager (15 min)
- Integration: Firebase Performance, Datadog

**Slack**:
- #incidents: Auto-created thread per incident
- #alerts: Grouped by alert type
- #ops: Daily digest format

**Email**:
- Distribution list: platform-team@example.com
- Format: Plain text with runbook link

---

## Appendix

### Related Documentation

- [Dashboard Configuration](../dashboards/staging_timeclock_dashboard.json)
- [Latency Probe](../../tools/perf/latency_probe.ts)
- [SLO Definitions](../../docs/architecture/slo.md)
- [Incident Response Playbook](../../docs/ops/incident_response.md)

### Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2025-10-11 | Initial version | Claude Code |

### Feedback

For questions or suggestions:
- Slack: #platform-team
- Email: platform-team@example.com
- GitHub Issues: tag `ops` and `alerting`
