# Epic B: Time Clock

## Overview
Core time tracking functionality enabling painters to clock in/out with offline support, GPS verification, and accurate hour calculation.

## Goals
- Reliable clock-in/out even when offline
- GPS-based job site verification
- Prevent duplicate/overlapping entries
- Accurate hour calculation for payroll
- Self-service timesheet viewing

## Stories

### V1 (MVP Foundation)
- **B1**: Clock-in (offline + GPS + idempotent) (P0, M, M)
  - Offline queue with automatic sync
  - GPS permission and capture
  - Idempotency to prevent duplicates
  - Optimistic UI for instant feedback
  
- **B2**: Clock-out + Overlap Guard (P0, M, M)
  - Close open time entries
  - Calculate hours worked
  - Prevent overlapping shifts
  - Offline support
  
- **B3**: Jobs Today (Assigned Only) (P0, S, L)
  - View assigned jobs for current day
  - Quick access to clock in/out
  - Offline caching
  
- **B4**: Location Permission UX (P0, S, L)
  - Clear permission rationale
  - Non-blocking if denied
  - Settings deep-link

### V2 (Automation & Self-Service)
- **B5**: Auto Clock-out Safety (P1, M, M)
  - Automatic clock-out after 12 hours
  - Warning notifications at 10 hours
  
- **B7**: My Timesheet (Weekly View) (P1, M, L)
  - View personal time entries for week
  - Total hours summary
  - Pending sync indicator

### Future Enhancements (V3-V4)
- **B6**: Break Tracking
- **B8**: Admin Time Entry Edit
- **B9**: Time Entry Notes/Photos

## Key Data Models

### Time Entry
```
jobs/{jobId}/timeEntries/{entryId}
  orgId: string
  userId: string
  jobId: string
  clockIn: Timestamp
  clockOut: Timestamp | null
  durationMinutes: number | null
  geo: { lat, lng } | null
  gpsMissing: boolean
  clientId: string  // For idempotency
  source: 'mobile' | 'web'
  createdAt: Timestamp
  updatedAt: Timestamp
```

### Offline Queue Item
```dart
class QueueItem {
  String id;
  String operation; // 'clock_in' | 'clock_out'
  Map<String, dynamic> data;
  bool processed;
  DateTime createdAt;
}
```

## Technical Approach

### Offline Strategy
- Hive local database for queue persistence
- Automatic sync on network reconnect
- Optimistic UI updates
- Idempotency keys prevent duplicates

### GPS Strategy
- Coarse location (city block level)
- Request only during clock-in/out
- Non-blocking if permission denied
- Flag entries with `gpsMissing=true`

## Success Metrics
- Clock-in success rate (online): >99%
- Offline sync success rate: >95%
- Clock-in latency: P95 <2.5s (online)
- GPS capture rate: >80% (target)
- Duplicate entry rate: <0.1%

## Dependencies
- Epic A: Authentication (blocking)
- Firebase Firestore with offline persistence
- Flutter packages: `geolocator`, `hive`, `connectivity_plus`

## References
- [ADR-006: Idempotency Strategy](../../adrs/006-idempotency-strategy.md)
- [ADR-011: Story-Driven Development](../../adrs/011-story-driven-development.md)
