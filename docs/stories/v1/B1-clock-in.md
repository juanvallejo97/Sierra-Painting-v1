# B1: Clock-in (offline + GPS + idempotent)

**Epic**: B (Time Clock) | **Priority**: P0 | **Sprint**: V1 | **Est**: M | **Risk**: M

## User Story
As a Painter, I WANT to clock-in even when offline, SO THAT no time is lost.

## Dependencies
- **A1** (Sign-in): Must be authenticated to clock in
- **A5** (App Check): API protection required

## Acceptance Criteria (BDD)

### Success Scenario: Online Clock-in
**GIVEN** I am signed in and on the Jobs Today screen  
**AND** I have network connectivity  
**WHEN** I tap "Clock In" on an assigned job  
**THEN** I see optimistic UI update within 500ms  
**AND** server write completes in P95 ≤ 2.5s  
**AND** I see confirmation "Clocked in at [time]"

### Success Scenario: Offline Clock-in
**GIVEN** I am signed in but offline (no network)  
**WHEN** I tap "Clock In" on an assigned job  
**THEN** I see "Pending Sync" chip within 500ms  
**AND** entry is queued locally with clientId  
**WHEN** network reconnects  
**THEN** queue syncs to server automatically  
**AND** only ONE server entry is created (idempotent)  
**AND** "Pending Sync" chip disappears

### Success Scenario: GPS Permission Granted
**GIVEN** I am clocking in for the first time  
**WHEN** the app requests location permission  
**AND** I grant permission  
**THEN** coarse lat/lng is captured with clock-in  
**AND** I see "Location captured" confirmation

### Edge Case: GPS Permission Denied
**GIVEN** I am clocking in  
**WHEN** I deny location permission  
**THEN** clock-in proceeds anyway  
**AND** entry saved with `gpsMissing=true`  
**AND** I see "Location not captured" message  
**AND** clock-in is NOT blocked

### Edge Case: Duplicate Clock-in
**GIVEN** I have an open clock-in for Job A  
**WHEN** I try to clock in again for Job A  
**THEN** I see error "You have an open shift for this job"  
**AND** no duplicate entry is created

### Edge Case: Offline → Online Duplicate Prevention
**GIVEN** I clocked in offline (queued locally)  
**WHEN** network reconnects and queue syncs  
**AND** I try to clock in again before sync completes  
**THEN** only ONE server entry is created  
**AND** clientId ensures idempotency

### Accessibility
- "Clock In" button: minimum 48×48 touch target
- Button labeled "Clock In for [Job Name]"
- "Pending Sync" chip: high contrast, screen reader announces state
- Location permission dialog: clear rationale text

### Performance
- **Target**: Optimistic UI ≤ 500ms, server write P95 ≤ 2.5s
- **Metric**: `clock_in_duration_ms` (client → server confirmed)

## Data Models

### Zod Schema
```typescript
const TimeInSchema = z.object({
  jobId: z.string().min(8),
  at: z.number().int().positive(),  // Epoch milliseconds
  geo: z.object({
    lat: z.number(),
    lng: z.number(),
  }).optional(),
  clientId: z.string().uuid(),      // For idempotency
});

export type TimeIn = z.infer<typeof TimeInSchema>;
```

### Firestore Structure
```
jobs/{jobId}/timeEntries/{entryId}
  orgId: string
  userId: string
  clockIn: number          // Epoch ms (server timestamp)
  clockOut: number | null
  geo: { lat, lng } | null
  gpsMissing: boolean
  clientId: string         // For idempotency
  source: 'mobile' | 'web'
  createdAt: Timestamp
  updatedAt: Timestamp
```

### Indexes Required
```javascript
// Composite index for querying user's entries
{
  collectionGroup: 'timeEntries',
  fields: [
    { fieldPath: 'userId', order: 'ASCENDING' },
    { fieldPath: 'clockIn', order: 'DESCENDING' }
  ]
}
```

## Security

### Firestore Rules
```javascript
match /jobs/{jobId}/timeEntries/{entryId} {
  // Users can create their own entries
  allow create: if request.auth != null
    && request.resource.data.userId == request.auth.uid
    && request.resource.data.orgId == 
       get(/databases/$(database)/documents/users/$(request.auth.uid)).data.orgId;
  
  // Users can read their own entries OR admins can read all
  allow read: if request.auth != null 
    && (request.auth.uid == resource.data.userId 
        || get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin');
  
  // No client updates (clock-out is via callable function)
  allow update, delete: if false;
}
```

### Validation
- **Client-side**: Zod schema before queueing
- **Server-side**: Callable function validates job exists, user assigned, no open entry

## API Contracts

### Cloud Function: `clockIn`
```typescript
export const clockIn = functions
  .runWith({ enforceAppCheck: true })
  .https.onCall(async (data, context) => {
    // 1. Verify authentication
    if (!context.auth) throw HttpsError('unauthenticated');
    
    // 2. Validate input
    const validated = TimeInSchema.parse(data);
    
    // 3. Check idempotency
    const idempotencyKey = `clock_in:${validated.jobId}:${validated.clientId}`;
    const existing = await db.collection('idempotency').doc(idempotencyKey).get();
    if (existing.exists) {
      return existing.data()?.result;
    }
    
    // 4. Verify job exists and user is assigned
    const jobDoc = await db.collection('jobs').doc(validated.jobId).get();
    if (!jobDoc.exists) throw HttpsError('not-found', 'Job not found');
    if (!jobDoc.data()?.crewIds.includes(context.auth.uid)) {
      throw HttpsError('permission-denied', 'Not assigned to this job');
    }
    
    // 5. Check for existing open entry
    const openEntries = await db.collectionGroup('timeEntries')
      .where('userId', '==', context.auth.uid)
      .where('jobId', '==', validated.jobId)
      .where('clockOut', '==', null)
      .limit(1)
      .get();
    
    if (!openEntries.empty) {
      throw HttpsError('failed-precondition', 'Open shift already exists');
    }
    
    // 6. Create time entry
    const entryRef = await db.collection('jobs').doc(validated.jobId)
      .collection('timeEntries').add({
        orgId: jobDoc.data()?.orgId,
        userId: context.auth.uid,
        jobId: validated.jobId,
        clockIn: admin.firestore.FieldValue.serverTimestamp(),
        clockOut: null,
        geo: validated.geo || null,
        gpsMissing: !validated.geo,
        clientId: validated.clientId,
        source: context.rawRequest.headers['user-agent']?.includes('mobile') ? 'mobile' : 'web',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    
    // 7. Store idempotency record
    const result = { success: true, entryId: entryRef.id };
    await db.collection('idempotency').doc(idempotencyKey).set({
      key: idempotencyKey,
      operation: 'clock_in',
      resourceId: entryRef.id,
      result,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 48 * 60 * 60 * 1000)
      ),
    });
    
    // 8. Log telemetry
    functions.logger.info('Clock-in success', {
      userId: context.auth.uid,
      jobId: validated.jobId,
      hasGeo: !!validated.geo,
    });
    
    return result;
  });
```

## Telemetry

### Analytics Events
- `clock_in`: Successful clock-in (online)
  - Properties: `jobId`, `hasGeo`, `source`
- `clock_in_offline`: Queued for offline sync
  - Properties: `jobId`, `hasGeo`
- `clock_in_no_gps`: Clock-in without GPS permission
  - Properties: `jobId`
- `clock_overlap_blocked`: Duplicate clock-in prevented
  - Properties: `jobId`, `existingEntryId`

### Audit Log Entries
```typescript
// Created in activity_logs collection
{
  timestamp: Timestamp,
  entity: 'time_entry',
  action: 'TIME_IN',
  actorUid: string,
  orgId: string,
  details: {
    jobId: string,
    entryId: string,
    geo: { lat, lng } | null,
    source: 'mobile' | 'web'
  }
}
```

## Testing Strategy

### Unit Tests
- `TimeInSchema` validation: valid input passes, invalid fails
- `clockIn` function: mocked Firestore calls
- Idempotency key generation: consistent format
- Open entry detection: query returns existing entry

### Integration Tests (Emulator)
- **Test 1**: Clock-in with GPS → entry created with geo
- **Test 2**: Clock-in without GPS → entry created with gpsMissing=true
- **Test 3**: Duplicate clock-in → error thrown, no duplicate entry
- **Test 4**: Idempotency → same clientId returns cached result
- **Test 5**: Unassigned user → permission denied

### E2E Tests (Flutter)
- **Test 1**: Online clock-in → see confirmation within 2.5s
- **Test 2**: Offline clock-in → see "Pending Sync" → reconnect → entry syncs
- **Test 3**: Deny GPS → clock-in succeeds, see "Location not captured"

## UI Components

### Clock-in Button
```dart
ElevatedButton(
  onPressed: _isLoading ? null : () => _handleClockIn(),
  child: _isLoading 
    ? CircularProgressIndicator()
    : Text('Clock In for ${job.name}'),
  style: ElevatedButton.styleFrom(
    minimumSize: Size(double.infinity, 48), // Accessible height
  ),
)
```

### Pending Sync Chip
```dart
if (queueItem.processed == false)
  Chip(
    avatar: Icon(Icons.cloud_off, size: 16),
    label: Text('Pending Sync'),
    backgroundColor: Colors.orange.shade100,
  )
```

### Location Permission Dialog
```dart
AlertDialog(
  title: Text('Location Permission'),
  content: Text(
    'We use your location to verify you\'re at the job site. '
    'This helps with accurate time tracking and payroll.'
  ),
  actions: [
    TextButton(
      onPressed: () => Navigator.pop(context, false),
      child: Text('Deny'),
    ),
    ElevatedButton(
      onPressed: () => Navigator.pop(context, true),
      child: Text('Allow'),
    ),
  ],
)
```

## Definition of Ready (DoR)
- [x] **A1** (Sign-in) completed
- [x] **A5** (App Check) enabled
- [x] Zod schema defined
- [x] Firestore rules drafted
- [x] Indexes created
- [x] UI mockups reviewed
- [x] Performance targets agreed (500ms UI, 2.5s server)

## Definition of Done (DoD)
- [ ] `clockIn` callable function implemented
- [ ] Client-side offline queue implemented
- [ ] GPS permission handling implemented
- [ ] Idempotency with clientId working
- [ ] Open entry duplicate check working
- [ ] Unit tests pass (≥80% coverage)
- [ ] Integration tests pass (emulator)
- [ ] E2E test: offline → online sync
- [ ] Telemetry events wired
- [ ] Audit log entry created
- [ ] Firestore rules deployed to staging
- [ ] Index created in staging
- [ ] Demo: clock-in offline → reconnect → verify one entry
- [ ] Performance: P95 ≤ 2.5s verified

## Notes

### Implementation Tips
- Use `uuid` package for clientId generation: `const uuid = require('uuid')`
- Store queue items in Hive with generated `clientId`
- On network reconnect, batch sync queue items (max 10 at a time)
- Use `connectivity_plus` package to detect network state

### Gotchas
- **DST Changes**: Store epoch milliseconds, display in local timezone
- **Clock Skew**: Server timestamp is source of truth, not client time
- **GPS Accuracy**: Use coarse location (city block level), not fine GPS
- **Battery**: Request location only during clock-in, not continuous

### References
- [ADR-006: Idempotency Strategy](../../adrs/006-idempotency-strategy.md)
- [ADR-003: Offline-First Architecture](../../adrs/003-offline-first.md)
- [Geolocator Package](https://pub.dev/packages/geolocator)
- [UUID Package](https://pub.dev/packages/uuid)
