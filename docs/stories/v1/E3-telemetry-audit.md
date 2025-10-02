# E3: Telemetry + Audit Log

**Epic**: E (Operations & Observability) | **Priority**: P0 | **Sprint**: V1 | **Est**: S | **Risk**: L

## User Story
As a System Administrator, I WANT telemetry and audit logs, SO THAT I can monitor system health and track actions.

## Dependencies
- **A1** (Sign-in): Need user context for audit logs

## Acceptance Criteria (BDD)

### Success Scenario: Analytics Events
**GIVEN** a user clocks in  
**WHEN** the operation completes  
**THEN** `clock_in` event is logged to Firebase Analytics  
**AND** event includes: `userId`, `jobId`, `hasGeo`

### Success Scenario: Audit Log Entry
**GIVEN** an admin changes a user's role  
**WHEN** the operation completes  
**THEN** audit log entry is created in Firestore  
**AND** entry includes: timestamp, action, actor, entity, details

### Success Scenario: Error Tracking
**GIVEN** a function throws an error  
**WHEN** the error is caught  
**THEN** error event is logged to Firebase Analytics  
**AND** error details are in Cloud Logging

### Accessibility
- No UI impact (backend feature)

### Performance
- **Target**: Logging adds ≤ 10ms to operation latency
- **Metric**: Time difference with/without logging

## Data Models

### Audit Log Structure
```
activity_logs/{logId}
  timestamp: Timestamp
  entity: 'time_entry' | 'user_role' | 'job' | 'invoice'
  action: 'TIME_IN' | 'TIME_OUT' | 'ROLE_CHANGED' | 'CREATED' | etc.
  actorUid: string
  orgId: string
  details: object  // Action-specific data
```

### Analytics Event Format
```typescript
analytics.logEvent('clock_in', {
  userId: string,
  jobId: string,
  hasGeo: boolean,
  source: 'mobile' | 'web',
});
```

## Implementation

### Audit Log Service
```typescript
// functions/src/services/audit-log.ts
export async function logAuditEntry(params: {
  entity: string;
  action: string;
  actorUid: string;
  orgId: string;
  details: any;
}) {
  await db.collection('activity_logs').add({
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    entity: params.entity,
    action: params.action,
    actorUid: params.actorUid,
    orgId: params.orgId,
    details: params.details,
  });
}

// Usage in clockIn function:
await logAuditEntry({
  entity: 'time_entry',
  action: 'TIME_IN',
  actorUid: context.auth.uid,
  orgId: jobDoc.data()?.orgId,
  details: {
    jobId: validated.jobId,
    entryId: entryRef.id,
    geo: validated.geo || null,
    source: 'mobile',
  },
});
```

### Firebase Analytics (Flutter)
```dart
// lib/core/services/analytics_service.dart
import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  
  Future<void> logClockIn({
    required String jobId,
    required bool hasGeo,
  }) async {
    await _analytics.logEvent(
      name: 'clock_in',
      parameters: {
        'job_id': jobId,
        'has_geo': hasGeo,
        'source': 'mobile',
      },
    );
  }
  
  Future<void> logError({
    required String error,
    String? context,
  }) async {
    await _analytics.logEvent(
      name: 'app_error',
      parameters: {
        'error': error,
        'context': context,
      },
    );
  }
}
```

## Security

### Firestore Rules
```javascript
match /activity_logs/{logId} {
  // Only admins can read audit logs
  allow read: if request.auth != null
    && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin'
    && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.orgId == resource.data.orgId;
  
  // Only cloud functions can write
  allow write: if false;
}
```

## Definition of Done (DoD)
- [ ] Audit log service implemented in functions
- [ ] Analytics service implemented in Flutter
- [ ] All key operations log audit entries (clock-in, clock-out, role change)
- [ ] All key operations log analytics events
- [ ] Error tracking implemented
- [ ] Firestore rules for activity_logs deployed
- [ ] Demo: perform action → see audit log entry → see analytics event in Firebase Console

## Notes

### Implementation Tips
- Audit logs are for compliance, analytics for product insights
- Don't log PII in analytics (use hashed IDs)
- Set retention policy for audit logs (e.g., 7 years for time tracking)
- Use Cloud Logging for operational logs, Analytics for user behavior

### References
- [Firebase Analytics Documentation](https://firebase.google.com/docs/analytics)
- [Cloud Logging](https://cloud.google.com/logging/docs)
- [ADR-011: Story-Driven Development](../../adrs/011-story-driven-development.md)
