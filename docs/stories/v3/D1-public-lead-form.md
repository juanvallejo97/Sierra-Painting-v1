# D1: Public Lead Form

**Epic**: D (Lead Management) | **Priority**: P0 | **Sprint**: V3 | **Est**: M | **Risk**: L

## User Story
As a Potential Customer, I WANT to submit a lead form, SO THAT I can request a quote.

## Acceptance Criteria

### Success Scenario
**GIVEN** I visit the public lead form page  
**WHEN** I fill out my info and submit  
**THEN** lead is created and I see "Thank you" message

## Data Models

```
leads/{leadId}
  customerName: string
  email: string
  phone: string
  address: string
  serviceType: 'interior' | 'exterior' | 'commercial'
  description: string
  photoUrls: string[]
  status: 'new'
  createdAt: Timestamp
```

## API Contracts

```typescript
export const submitLead = functions.https.onCall(async (data, context) => {
  // 1. Verify reCAPTCHA
  // 2. Validate input
  // 3. Create lead document
  // 4. Send email notification to admin
  // 5. Return success
});
```

## Definition of Done
- [ ] Public form hosted
- [ ] reCAPTCHA working
- [ ] Lead document created
- [ ] Email notification sent
- [ ] E2E test: submit form → lead created

## References
- [ADR-011: Story-Driven Development](../../adrs/011-story-driven-development.md)
