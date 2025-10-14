# D2: Admin Review Lead

**Epic**: D (Lead Management) | **Priority**: P0 | **Sprint**: V3 | **Est**: M | **Risk**: M

## User Story
As an Admin, I WANT to review submitted leads, SO THAT I can qualify them and convert to jobs.

## Dependencies
- **D1** (Public Lead Form): Must have leads to review
- **A1** (Sign-in): Must be authenticated as admin

## Acceptance Criteria

### Success Scenario
**GIVEN** I am signed in as admin  
**WHEN** I view the Leads screen  
**THEN** I see all new leads with customer info

## API Contracts

```typescript
export const qualifyLead = functions.https.onCall(async (data, context) => {
  // 1. Verify admin
  // 2. Update lead status to 'qualified'
  // 3. Add notes
  // 4. Return success
});
```

## Definition of Done
- [ ] Leads screen implemented
- [ ] Qualify/disqualify actions working
- [ ] Notes can be added
- [ ] E2E test: review lead → qualify → status updated

## References
- [ADR-011: Story-Driven Development](../../adrs/011-story-driven-development.md)
