# Reliability and SRE

This document outlines the Service Level Objectives (SLOs), incident response procedures, and alerting configuration for Sierra Painting.

## Service Level Objectives (SLOs)

### Performance SLOs
- **Web LCP (Largest Contentful Paint)**: ≤ 2.5s at p75 (75th percentile)
- **API Latency**: ≤ 400ms at p95 (95th percentile) for Cloud Functions
- **Firestore Query Response**: ≤ 200ms at p95

### Reliability SLOs
- **Crash-free sessions**: ≥ 99.5% (mobile app)
- **Uptime**: ≥ 99.9% for Firebase services (measured monthly)
- **Function Success Rate**: ≥ 99.5% for critical Cloud Functions

### Error Budgets
- **Monthly Error Budget**: 0.1% downtime = ~43 minutes per month
- **Daily Error Budget**: ~4 minutes per day

## Incident Response

### Severity Levels

#### P0 (Critical)
- **Definition**: Complete service outage or data loss
- **Response Time**: 15 minutes
- **Examples**: Firebase project down, payment processing broken

#### P1 (High)
- **Definition**: Major feature degraded, affecting >50% of users
- **Response Time**: 1 hour
- **Examples**: Authentication failing for some users, slow API responses

#### P2 (Medium)
- **Definition**: Minor feature degraded or affecting <10% of users
- **Response Time**: 4 hours
- **Examples**: UI glitch, non-critical function slow

#### P3 (Low)
- **Definition**: Cosmetic issues or feature requests
- **Response Time**: Next business day

### Incident Playbooks

#### Triage Template
1. **Detect**: Alert received or user report
2. **Assess**: Determine severity level
3. **Notify**: Alert team via designated channel (TODO: configure Slack/email)
4. **Investigate**: Check logs, metrics, recent deployments
5. **Mitigate**: Rollback or hotfix
6. **Resolve**: Verify fix in production
7. **Post-mortem**: Document root cause and action items

#### Disaster Recovery and Rollback Steps
1. **Identify Bad Deployment**
   - Check GitHub Actions history
   - Review Firebase deployment logs
   - Identify specific commit/tag

2. **Rollback Cloud Functions**
   ```bash
   # List recent deployments
   firebase functions:log --only <function-name>
   
   # Rollback to previous version (manual)
   git checkout <previous-commit>
   npm run build
   firebase deploy --only functions --project <project-id>
   ```

3. **Rollback Firestore Rules**
   ```bash
   # Rules are versioned in Git; revert and redeploy
   git checkout <previous-commit> -- firestore.rules
   firebase deploy --only firestore:rules --project <project-id>
   ```

4. **Rollback Flutter App**
   - Push critical hotfix to main
   - Build and deploy new version
   - For emergency: point users to previous version via Remote Config

5. **Verify Rollback**
   - Test critical user flows
   - Monitor metrics for 30 minutes
   - Confirm error rates return to baseline

## Alerting

### Monitoring Configuration

**TODO**: Configure GCP Cloud Monitoring alerts with the following thresholds:

#### Performance Alerts
- **API Latency**: Alert if p95 > 500ms for 5 minutes
- **Function Errors**: Alert if error rate > 1% for 10 minutes
- **Firestore Read/Write Latency**: Alert if p95 > 300ms for 5 minutes

#### Reliability Alerts
- **Function Crash Rate**: Alert if crash rate > 0.5% for 10 minutes
- **Auth Failure Rate**: Alert if auth failures > 5% for 5 minutes
- **Storage Quota**: Alert if approaching 80% of storage limit

#### Security Alerts
- **App Check Invalid Rate**: Alert if invalid requests > 10% for 10 minutes
- **Failed Login Attempts**: Alert if rate > 100/minute for 5 minutes
- **Firestore Rules Denials**: Alert if denial rate increases 5x over baseline

### Alert Destinations

**TODO**: Configure alert channels:
- **Slack**: #alerts channel (high priority)
- **Email**: on-call rotation list
- **PagerDuty**: For P0/P1 incidents (optional)

**Placeholder**: Add webhook URLs and API keys in GCP Console > Monitoring > Alerting > Notification Channels

### On-Call Rotation

**TODO**: Establish on-call schedule using PagerDuty or Google Calendar
- Weekly rotation
- Primary and backup on-call
- Escalation policy: 15 min → backup → manager

## Metrics Dashboard

**TODO**: Create Cloud Monitoring dashboard with:
- API latency charts (p50, p95, p99)
- Error rate by function
- Active users
- Firestore read/write operations
- Storage usage
- App Check metrics

**Access**: [GCP Console](https://console.cloud.google.com/monitoring) > Dashboards > Sierra Painting Production

## Related Documentation
- [Deployment Checklist](../deployment_checklist.md)
- [Testing Guide](../Testing.md)
- [Architecture Overview](../Architecture.md)

## Notes
- This document is a living document; update as SLOs and procedures evolve
- Review and adjust SLOs quarterly based on actual metrics
- Conduct incident post-mortems within 48 hours of resolution
- Archive post-mortems in this directory for future reference
