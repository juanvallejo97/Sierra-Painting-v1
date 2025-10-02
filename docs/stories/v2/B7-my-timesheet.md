# B7: My Timesheet (Weekly View)

**Epic**: B (Time Clock) | **Priority**: P1 | **Sprint**: V2 | **Est**: M | **Risk**: L

## User Story
As a Painter, I WANT to view my timesheet for the week, SO THAT I can verify my hours before payroll.

## Dependencies
- **B1** (Clock-in), **B2** (Clock-out): Must have time entries to display

## Acceptance Criteria (BDD)

### Success Scenario: View Weekly Timesheet
**GIVEN** I am signed in as a painter  
**WHEN** I navigate to "My Timesheet"  
**THEN** I see all my time entries for the current week  
**AND** I see total hours for the week  
**AND** each entry shows: job name, date, clock-in time, clock-out time, hours

### Success Scenario: Navigate Weeks
**GIVEN** I am viewing current week's timesheet  
**WHEN** I tap "Previous Week"  
**THEN** I see entries from last week  
**AND** total hours updates

### Edge Case: No Entries for Week
**GIVEN** I have no time entries for a week  
**WHEN** I view that week's timesheet  
**THEN** I see "No hours worked this week"  
**AND** total shows 0 hours

### Edge Case: Pending Sync Entries
**GIVEN** I have offline entries not yet synced  
**WHEN** I view my timesheet  
**THEN** I see "Pending Sync" badge on those entries  
**AND** they are included in total with note

## Data Models

### Query
```typescript
// Query user's entries for date range
db.collectionGroup('timeEntries')
  .where('userId', '==', userId)
  .where('clockIn', '>=', weekStart)
  .where('clockIn', '<=', weekEnd)
  .orderBy('clockIn', 'desc')
```

## UI Components

```dart
// Timesheet screen with week selector
ListView(
  children: [
    WeekSelector(
      currentWeek: selectedWeek,
      onPrevious: () => setState(...),
      onNext: () => setState(...),
    ),
    TotalHoursTile(hours: totalHours),
    ...timeEntries.map((entry) => TimeEntryCard(entry)),
  ],
)
```

## Definition of Done (DoD)
- [ ] Timesheet screen implemented
- [ ] Week navigation working
- [ ] Total hours calculated correctly
- [ ] Pending sync indicator shown
- [ ] E2E test: clock in/out → view timesheet → see entry
- [ ] Performance: P95 ≤ 2s load time

## References
- [ADR-011: Story-Driven Development](../../adrs/011-story-driven-development.md)
