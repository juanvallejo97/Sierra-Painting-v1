# B2: Clock-out + Overlap Guard

**Epic**: B (Time Clock) | **Priority**: P0 | **Sprint**: V1 | **Est**: M | **Risk**: M

## User Story
As a Painter, I WANT to clock out when I finish work, SO THAT my hours are accurately recorded.

## Dependencies
- **A1** (Sign-in): Must be authenticated
- **B1** (Clock-in): Must have an open clock-in to clock out

## Acceptance Criteria (BDD)

### Success Scenario: Clock-out
**GIVEN** I have an open clock-in entry  
**WHEN** I tap "Clock Out"  
**THEN** my shift is closed within 2.5 seconds  
**AND** I see "Clocked out at [time]"  
**AND** I see total hours worked (e.g., "4h 30m")

### Success Scenario: Offline Clock-out
**GIVEN** I have an open clock-in and no network  
**WHEN** I tap "Clock Out"  
**THEN** I see "Pending Sync" chip within 500ms  
**AND** clock-out is queued locally  
**WHEN** network reconnects  
**THEN** clock-out syncs automatically  
**AND** hours are calculated correctly

### Edge Case: No Open Clock-in
**GIVEN** I have no open clock-in entries  
**WHEN** I try to clock out  
**THEN** I see error "No open shift found"  
**AND** clock-out is blocked

### Edge Case: Multiple Jobs Clocked In
**GIVEN** I have open clock-ins for Job A and Job B  
**WHEN** I navigate to Job A and tap "Clock Out"  
**THEN** only Job A's entry is closed  
**AND** Job B remains open

### Edge Case: Clock-out Before Clock-in
**GIVEN** offline queue has: clock-in pending, then clock-out pending  
**WHEN** network reconnects  
**THEN** clock-in syncs first, then clock-out  
**AND** both operations succeed in correct order

### Accessibility
- "Clock Out" button minimum 48×48 touch target
- Hours worked announced by screen reader
- Pending sync status clearly indicated

### Performance
- **Target**: Clock-out P95 ≤ 2.5 seconds (online)
- **Metric**: Time from tap "Clock Out" to confirmation

## Data Models

### Zod Schema
```typescript
const TimeOutSchema = z.object({
  entryId: z.string().min(8),
  at: z.number().int().positive(),  // Epoch milliseconds
  clientId: z.string().uuid(),      // For idempotency
});

export type TimeOut = z.infer<typeof TimeOutSchema>;
```

### Firestore Structure (Update)
```
jobs/{jobId}/timeEntries/{entryId}
  orgId: string
  userId: string
  clockIn: number
  clockOut: number | null  ← Updated by clock-out
  durationMinutes: number | null  ← Calculated
  geo: { lat, lng } | null
  gpsMissing: boolean
  clientId: string
  source: 'mobile' | 'web'
  createdAt: Timestamp
  updatedAt: Timestamp  ← Updated by clock-out
```

### Indexes Required
```javascript
// Composite index for finding open entries
{
  collectionGroup: 'timeEntries',
  fields: [
    { fieldPath: 'userId', order: 'ASCENDING' },
    { fieldPath: 'clockOut', order: 'ASCENDING' },
    { fieldPath: 'clockIn', order: 'DESCENDING' }
  ]
}
```

## Security

### Firestore Rules
```javascript
match /jobs/{jobId}/timeEntries/{entryId} {
  // Clock-out via callable function only
  allow update: if false;
  
  // Users can read their own entries
  allow read: if request.auth != null 
    && (request.auth.uid == resource.data.userId 
        || get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin');
}
```

### Validation
- **Client-side**: Zod schema validates entryId and timestamp
- **Server-side**: Function verifies entry exists, belongs to user, is open

## API Contracts

### Cloud Function: `clockOut`
```typescript
export const clockOut = functions
  .runWith({ enforceAppCheck: true })
  .https.onCall(async (data, context) => {
    // 1. Verify authentication
    if (!context.auth) throw new HttpsError('unauthenticated');
    
    // 2. Validate input
    const validated = TimeOutSchema.parse(data);
    
    // 3. Check idempotency
    const idempotencyKey = `clock_out:${validated.entryId}:${validated.clientId}`;
    const existing = await db.collection('idempotency').doc(idempotencyKey).get();
    if (existing.exists) {
      return existing.data()?.result;
    }
    
    // 4. Find the entry
    const entryRef = await db.collectionGroup('timeEntries')
      .where('userId', '==', context.auth.uid)
      .where(admin.firestore.FieldPath.documentId(), '==', validated.entryId)
      .limit(1)
      .get();
    
    if (entryRef.empty) {
      throw new HttpsError('not-found', 'Time entry not found');
    }
    
    const entry = entryRef.docs[0];
    const entryData = entry.data();
    
    // 5. Verify entry is open (no clock-out)
    if (entryData.clockOut !== null) {
      throw new HttpsError('failed-precondition', 'Entry already closed');
    }
    
    // 6. Calculate duration
    const clockInMs = entryData.clockIn.toMillis ? entryData.clockIn.toMillis() : entryData.clockIn;
    const clockOutMs = validated.at;
    const durationMinutes = Math.round((clockOutMs - clockInMs) / 60000);
    
    // 7. Update entry
    await entry.ref.update({
      clockOut: admin.firestore.Timestamp.fromMillis(validated.at),
      durationMinutes,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // 8. Store idempotency record
    const result = { 
      success: true, 
      entryId: entry.id,
      durationMinutes 
    };
    await db.collection('idempotency').doc(idempotencyKey).set({
      key: idempotencyKey,
      operation: 'clock_out',
      resourceId: entry.id,
      result,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 48 * 60 * 60 * 1000)
      ),
    });
    
    // 9. Log telemetry
    functions.logger.info('Clock-out success', {
      userId: context.auth.uid,
      entryId: entry.id,
      durationMinutes,
    });
    
    return result;
  });
```

## Telemetry

### Analytics Events
- `clock_out`: Successful clock-out (online)
  - Properties: `entryId`, `durationMinutes`, `source`
- `clock_out_offline`: Queued for offline sync
  - Properties: `entryId`
- `clock_out_no_entry`: Attempted clock-out with no open entry
  - Properties: `userId`

### Audit Log Entries
```typescript
{
  timestamp: Timestamp,
  entity: 'time_entry',
  action: 'TIME_OUT',
  actorUid: string,
  orgId: string,
  details: {
    entryId: string,
    jobId: string,
    durationMinutes: number,
    source: 'mobile' | 'web'
  }
}
```

## Testing Strategy

### Unit Tests
- `TimeOutSchema` validation: valid input passes
- Duration calculation: correct for various intervals
- Idempotency: same clientId returns cached result

### Integration Tests (Emulator)
- **Test 1**: Clock-out open entry → entry updated with clockOut
- **Test 2**: Clock-out already closed entry → error
- **Test 3**: Clock-out non-existent entry → not found error
- **Test 4**: Idempotency → same clientId doesn't duplicate

### E2E Tests (Flutter)
- **Test 1**: Clock in → clock out → see hours worked
- **Test 2**: Offline clock-out → reconnect → entry synced
- **Test 3**: No open entry → clock out → error shown

## Definition of Ready (DoR)
- [x] **B1** (Clock-in) completed
- [x] Zod schema defined
- [x] Firestore rules drafted
- [x] Indexes created
- [x] Performance targets agreed (2.5s)

## Definition of Done (DoD)
- [ ] `clockOut` callable function implemented
- [ ] Client-side clock-out UI implemented
- [ ] Offline queue for clock-out working
- [ ] Duration calculation accurate
- [ ] Idempotency with clientId working
- [ ] Unit tests pass
- [ ] Integration tests pass (emulator)
- [ ] E2E test: clock in → clock out → verify hours
- [ ] Telemetry events wired
- [ ] Firestore rules deployed to staging
- [ ] Demo: offline clock-out → reconnect → one entry updated
- [ ] Performance: P95 ≤ 2.5s verified

## Notes

### Implementation Tips
- Queue processing: clock-in operations must complete before clock-out
- Display hours in human format: "4h 30m" not "270 minutes"
- Consider overtime rules (over 8 hours/day triggers overtime badge)
- Optimistic UI: immediately show "Clocked out" even before server confirms

### Gotchas
- Time zones: always store UTC timestamps, convert to local for display
- Clock skew: use server timestamp, not client time
- Duration edge cases: overnight shifts span midnight (still correct with timestamps)
- Negative duration: theoretically impossible but check anyway

### References
- [ADR-006: Idempotency Strategy](../../adrs/006-idempotency-strategy.md)
- [ADR-011: Story-Driven Development](../../adrs/011-story-driven-development.md)
