# B5: Auto Clock-out Safety

**Epic**: B (Time Clock) | **Priority**: P1 | **Sprint**: V2 | **Est**: M | **Risk**: M

## User Story
As a System Administrator, I WANT automatic clock-out after 12 hours, SO THAT forgotten clock-ins don't corrupt payroll.

## Dependencies
- **B1** (Clock-in), **B2** (Clock-out): Core time tracking must exist

## Acceptance Criteria (BDD)

### Success Scenario: Auto Clock-out Triggered
**GIVEN** a painter has been clocked in for 12 hours  
**WHEN** the auto clock-out cron job runs  
**THEN** the entry is automatically clocked out  
**AND** notification is sent to painter and admin  
**AND** audit log entry is created with action "AUTO_CLOCK_OUT"

### Success Scenario: Warning Notification
**GIVEN** a painter has been clocked in for 10 hours  
**WHEN** the cron job runs  
**THEN** warning notification is sent  
**AND** no auto clock-out occurs yet

### Edge Case: Manually Clocked Out Before Auto
**GIVEN** auto clock-out is scheduled  
**WHEN** painter manually clocks out first  
**THEN** auto clock-out is skipped (entry already closed)

## Data Models

### Time Entry Update
```
jobs/{jobId}/timeEntries/{entryId}
  clockOut: Timestamp  ← Set by auto clock-out
  autoClockOut: true   ← Flag indicates automatic
  durationMinutes: number
```

## API Contracts

### Scheduled Function: `autoClockOut`
```typescript
export const autoClockOut = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    const now = Date.now();
    const twelveHoursAgo = now - (12 * 60 * 60 * 1000);
    
    // Query open entries > 12 hours old
    const openEntries = await db.collectionGroup('timeEntries')
      .where('clockOut', '==', null)
      .where('clockIn', '<', twelveHoursAgo)
      .get();
    
    // Auto clock-out each entry
    for (const entry of openEntries.docs) {
      await entry.ref.update({
        clockOut: admin.firestore.Timestamp.now(),
        autoClockOut: true,
        durationMinutes: Math.round((now - entry.data().clockIn) / 60000),
      });
      
      // Send notifications
      // Log audit entry
    }
  });
```

## Definition of Done (DoD)
- [ ] Scheduled function implemented (runs every 5 min)
- [ ] Auto clock-out working for 12+ hour entries
- [ ] Warning notifications at 10 hours
- [ ] Audit log created
- [ ] Integration tests pass
- [ ] Demo: create old entry → cron runs → entry closed

## References
- [ADR-011: Story-Driven Development](../../adrs/011-story-driven-development.md)
- [Cloud Scheduler](https://firebase.google.com/docs/functions/schedule-functions)
