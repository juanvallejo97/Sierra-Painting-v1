# B3: Jobs Today (Assigned Only)

**Epic**: B (Time Clock) | **Priority**: P0 | **Sprint**: V1 | **Est**: S | **Risk**: L

## User Story
As a Painter, I WANT to see my jobs for today, SO THAT I know where to work.

## Dependencies
- **A1** (Sign-in): Must be authenticated to see assigned jobs

## Acceptance Criteria (BDD)

### Success Scenario: View Jobs Today
**GIVEN** I am signed in and have 2 jobs assigned for today  
**WHEN** I open the app  
**THEN** I see a list of my 2 jobs  
**AND** each job shows: name, address, start time, crew members

### Success Scenario: No Jobs Today
**GIVEN** I am signed in and have no jobs assigned for today  
**WHEN** I open the app  
**THEN** I see "No jobs assigned for today"  
**AND** I see an empty state with helpful message

### Edge Case: Offline Loading
**GIVEN** I have no network connectivity  
**WHEN** I open the app  
**THEN** I see jobs from last successful sync (cached)  
**AND** I see "Offline mode" indicator

### Accessibility
- Job cards have clear labels for screen readers
- Clock-in buttons clearly associated with jobs
- Empty state is descriptive

### Performance
- **Target**: Jobs Today loads in P95 ≤ 2 seconds
- **Metric**: Time from app open to jobs rendered

## Data Models

### Firestore Structure
```
jobs/{jobId}
  orgId: string
  name: string
  address: string
  scheduledDate: string  // 'YYYY-MM-DD'
  crewIds: string[]      // Array of assigned user IDs
  status: 'scheduled' | 'in_progress' | 'completed'
  createdAt: Timestamp
  updatedAt: Timestamp
```

### Indexes Required
```javascript
{
  collection: 'jobs',
  fields: [
    { fieldPath: 'orgId', order: 'ASCENDING' },
    { fieldPath: 'scheduledDate', order: 'ASCENDING' },
    { fieldPath: 'crewIds', order: 'ASCENDING' }
  ]
}
```

## Security

### Firestore Rules
```javascript
match /jobs/{jobId} {
  // Painters can read jobs they're assigned to
  allow read: if request.auth != null
    && request.auth.uid in resource.data.crewIds;
  
  // Admins can read all jobs in their org
  allow read: if request.auth != null
    && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin'
    && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.orgId == resource.data.orgId;
}
```

## Telemetry

### Analytics Events
- `jobs_today_viewed`: User opened Jobs Today screen
  - Properties: `jobCount`, `source: 'online' | 'cached'`

## Testing Strategy

### Integration Tests (Emulator)
- **Test 1**: Query jobs for today → returns only assigned jobs
- **Test 2**: Query for user with no jobs → returns empty array
- **Test 3**: Firestore rules allow assigned user → read succeeds

### E2E Tests (Flutter)
- **Test 1**: Open app → see jobs list within 2s
- **Test 2**: Offline → see cached jobs

## Definition of Done (DoD)
- [ ] Jobs query implemented (assigned jobs for today)
- [ ] Jobs Today screen UI implemented
- [ ] Offline caching working
- [ ] Empty state implemented
- [ ] Integration tests pass
- [ ] E2E test: sign in → see jobs within 2s
- [ ] Firestore rules deployed to staging
- [ ] Performance: P95 ≤ 2s verified

## Notes

### Implementation Tips
- Use `where('crewIds', 'array-contains', userId)` for query
- Filter by `scheduledDate == today` in query
- Enable Firestore offline persistence for caching
- Sort by start time client-side

### References
- [ADR-011: Story-Driven Development](../../adrs/011-story-driven-development.md)
