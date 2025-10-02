# D3: Schedule Lite (Basic Job Creation)

**Epic**: D (Lead Management) | **Priority**: P0 | **Sprint**: V3 | **Est**: M | **Risk**: M

## User Story
As an Admin, I WANT to create jobs and assign crews, SO THAT painters know where to work.

## Dependencies
- **D2** (Review Lead): Typically converts qualified leads to jobs
- **A1** (Sign-in): Must be authenticated as admin

## Acceptance Criteria

### Success Scenario
**GIVEN** I have a qualified lead  
**WHEN** I convert it to a job with date and crew  
**THEN** job is created and appears in assigned painters' Jobs Today

## Data Models

```
jobs/{jobId}
  orgId: string
  name: string
  address: string
  scheduledDate: string  // 'YYYY-MM-DD'
  crewIds: string[]
  status: 'scheduled'
  leadId: string | null
  createdAt: Timestamp
```

## API Contracts

```typescript
export const createJob = functions.https.onCall(async (data, context) => {
  // 1. Verify admin
  // 2. Validate input
  // 3. Create job document
  // 4. Send notifications to crew
  // 5. Return job ID
});
```

## Definition of Done
- [ ] Job creation form implemented
- [ ] Crew assignment (multi-select) working
- [ ] Job appears in painters' Jobs Today (B3)
- [ ] E2E test: create job → painters see it

## References
- [ADR-011: Story-Driven Development](../../adrs/011-story-driven-development.md)
