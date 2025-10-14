# C3: Manual Mark Paid

**Epic**: C (Invoicing) | **Priority**: P0 | **Sprint**: V2 | **Est**: M | **Risk**: M

## User Story
As an Admin, I WANT to manually mark an invoice as paid, SO THAT I can track cash/check payments.

## Dependencies
- **C2** (Quote → Invoice): Must have invoices to mark paid

## Acceptance Criteria (BDD)

### Success Scenario: Mark Paid
**GIVEN** I have an unpaid invoice  
**WHEN** I mark it as paid with payment method "cash"  
**THEN** invoice status updates to "paid" within 2 seconds  
**AND** paidAt timestamp is set  
**AND** audit log entry is created

### Edge Case: Already Paid
**GIVEN** an invoice is already paid  
**WHEN** I try to mark it as paid again  
**THEN** I see error "Invoice already paid"

### Edge Case: Idempotency
**GIVEN** I mark invoice as paid  
**WHEN** network error causes retry with same clientId  
**THEN** only ONE paid status update occurs

## Data Models

### Zod Schema
```typescript
const MarkPaidSchema = z.object({
  invoiceId: z.string(),
  paymentMethod: z.enum(['cash', 'check', 'other']),
  clientId: z.string().uuid(),
});
```

## API Contracts

### Cloud Function: `markInvoicePaid`
```typescript
export const markInvoicePaid = functions
  .https.onCall(async (data, context) => {
    // 1. Verify admin
    // 2. Check idempotency
    // 3. Get invoice
    // 4. Verify not already paid
    // 5. Update status, paymentMethod, paidAt
    // 6. Log audit entry
    // 7. Return success
  });
```

## Definition of Done (DoD)
- [ ] `markInvoicePaid` function implemented
- [ ] Idempotency working
- [ ] Duplicate payment blocked
- [ ] Audit log created
- [ ] Integration tests pass
- [ ] Performance: P95 ≤ 2s verified

## References
- [ADR-006: Idempotency Strategy](../../adrs/006-idempotency-strategy.md)
- [ADR-011: Story-Driven Development](../../adrs/011-story-driven-development.md)
