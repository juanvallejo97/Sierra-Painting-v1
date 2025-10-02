# C6: Refund/Void

**Epic**: C (Invoicing) | **Priority**: P2 | **Sprint**: V4 | **Est**: M | **Risk**: M

## User Story
As an Admin, I WANT to refund or void invoices, SO THAT I can handle cancellations.

## Acceptance Criteria

### Success Scenario: Refund
**GIVEN** an invoice is paid via Stripe  
**WHEN** I refund it  
**THEN** Stripe refund is processed  
**AND** invoice status is "refunded"

### Success Scenario: Void
**GIVEN** an invoice is unpaid  
**WHEN** I void it  
**THEN** invoice status is "void"  
**AND** it is excluded from reports

## Definition of Done
- [ ] Refund action working (Stripe API)
- [ ] Void action working (status update)
- [ ] Audit logs created
- [ ] E2E test: refund invoice → Stripe refund processed

## References
- [Stripe Refunds](https://stripe.com/docs/api/refunds)
