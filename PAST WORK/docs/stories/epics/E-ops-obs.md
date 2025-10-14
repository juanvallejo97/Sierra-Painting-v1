# Epic E: Operations & Observability

## Overview
Foundational operational capabilities including CI/CD, testing infrastructure, telemetry, audit logging, and business intelligence dashboards.

## Goals
- Automated testing and deployment
- Security validation (Firestore rules)
- System health monitoring
- User behavior analytics
- Compliance audit trail
- Business KPIs and alerts

## Stories

### V1 (Foundation)
- **E1**: CI/CD Gates (P0, M, L)
  - GitHub Actions workflow
  - Lint, format, build, test checks
  - Automated deploy to staging on merge
  - Branch protection rules
  
- **E2**: Firestore Rules Tests (Initial) (P0, M, M)
  - Rules testing framework setup
  - Tests for time entry permissions
  - Tests for user document access
  - Tests for cross-org isolation
  
- **E3**: Telemetry + Audit Log (P0, S, L)
  - Firebase Analytics for user events
  - Audit log collection in Firestore
  - Error tracking in Cloud Logging
  - Key event tracking (clock-in, role change, etc.)

### V4 (Advanced Observability)
- **E4**: KPI Dashboard Tiles (P1, L, M)
  - Admin dashboard with key metrics
  - Active crew count (today)
  - Total hours worked (week/month)
  - Revenue (invoices paid this month)
  - Outstanding invoices count
  
- **E5**: Cost Alerts (P2, M, L)
  - Monitor Cloud Functions costs
  - Alert if daily spend exceeds threshold
  - Firebase performance monitoring
  - Anomaly detection

### Future Enhancements
- **E6**: Real-time Dashboard
- **E7**: Custom Reports
- **E8**: Data Export

## Key Data Models

### Audit Log Entry
```
activity_logs/{logId}
  timestamp: Timestamp
  entity: 'time_entry' | 'user_role' | 'job' | 'invoice' | 'lead'
  action: string  // ACTION_NAME in SCREAMING_SNAKE_CASE
  actorUid: string
  orgId: string
  details: object  // Action-specific data
```

### Analytics Event (Firebase Analytics)
```typescript
analytics.logEvent('event_name', {
  // Event-specific properties
  userId: string,
  orgId: string,
  // ...
});
```

### KPI Metrics (Aggregated)
```
metrics/{orgId}/daily/{date}
  activeCrewCount: number
  totalHoursWorked: number
  entriesCreated: number
  invoicesPaid: number
  invoicesUnpaid: number
  revenue: number
```

## Technical Approach

### CI/CD Pipeline
- GitHub Actions for automation
- Separate workflows for lint, test, deploy
- Staging environment for validation
- Production deploy requires manual approval

### Telemetry Strategy
- **Analytics**: User behavior, feature usage, errors
- **Audit Logs**: Compliance trail, who did what
- **Performance**: Cloud Functions execution time, cold starts
- **Costs**: Daily budget alerts, resource optimization

### Testing Strategy
- **Unit Tests**: Business logic, schema validation
- **Integration Tests**: Firestore rules, Cloud Functions with emulator
- **E2E Tests**: Critical user flows (sign-in → clock-in → clock-out)

## Success Metrics
- CI pipeline success rate: >95%
- CI pipeline duration: P95 <5 minutes
- Test coverage: >80%
- Firestore rules coverage: 100% (all collections)
- Audit log completeness: 100% (all critical actions logged)
- Dashboard load time: P95 <3 seconds
- Alert response time: <5 minutes for critical alerts

## Dependencies
- Epic A: Authentication (for audit logs)
- Epic B: Time Clock (for metrics)
- Epic C: Invoicing (for revenue metrics)
- GitHub Actions
- Firebase Analytics
- Cloud Monitoring & Logging

## References
- [ADR-011: Story-Driven Development](../../adrs/011-story-driven-development.md)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Firebase Analytics](https://firebase.google.com/docs/analytics)
- [Cloud Monitoring](https://cloud.google.com/monitoring/docs)
