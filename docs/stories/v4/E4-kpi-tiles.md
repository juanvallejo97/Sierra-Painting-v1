# E4: KPI Dashboard Tiles

**Epic**: E (Operations) | **Priority**: P1 | **Sprint**: V4 | **Est**: L | **Risk**: M

## User Story
As an Admin, I WANT to see key metrics on my dashboard, SO THAT I understand business health.

## Acceptance Criteria

### Success Scenario
**GIVEN** I am signed in as admin  
**WHEN** I open the dashboard  
**THEN** I see KPI tiles:
- Active crew count (today)
- Total hours worked (this week)
- Revenue (invoices paid this month)
- Outstanding invoices count

## Data Models

```
metrics/{orgId}/daily/{date}
  activeCrewCount: number
  totalHoursWorked: number
  revenue: number
  invoicesPaid: number
  invoicesUnpaid: number
```

## Definition of Done
- [ ] Dashboard tiles implemented
- [ ] Metrics aggregated daily (scheduled function)
- [ ] Real-time updates working
- [ ] E2E test: clock in → see active crew count increase

## References
- [ADR-011: Story-Driven Development](../../adrs/011-story-driven-development.md)
