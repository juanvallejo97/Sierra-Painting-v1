# C2: Quote → Invoice

**Epic**: C (Invoicing) | **Priority**: P0 | **Sprint**: V2 | **Est**: M | **Risk**: L

## User Story
As an Admin, I WANT to convert an accepted quote to an invoice, SO THAT I can request payment.

## Dependencies
- **C1** (Create Quote): Must have quotes to convert

## Acceptance Criteria (BDD)

### Success Scenario: Convert Quote
**GIVEN** I have an accepted quote  
**WHEN** I tap "Convert to Invoice"  
**THEN** invoice is created with same line items within 2 seconds  
**AND** quote status is updated to "converted"  
**AND** invoice status is "sent"

### Edge Case: Already Converted
**GIVEN** a quote has already been converted  
**WHEN** I try to convert it again  
**THEN** I see error "Quote already converted"

## Data Models

### Firestore Structure
```
invoices/{invoiceId}
  orgId: string
  quoteId: string
  customerId: string
  lineItems: Array (copied from quote)
  subtotal: number
  tax: number
  total: number
  status: 'sent' | 'paid' | 'void'
  paymentMethod: null
  paidAt: null
  createdAt: Timestamp
```

## API Contracts

### Cloud Function: `convertQuoteToInvoice`
```typescript
export const convertQuoteToInvoice = functions
  .https.onCall(async (data, context) => {
    // 1. Verify admin
    // 2. Get quote document
    // 3. Verify not already converted
    // 4. Create invoice with same data
    // 5. Update quote status
    // 6. Return invoice ID
  });
```

## Definition of Done (DoD)
- [ ] `convertQuoteToInvoice` function implemented
- [ ] Line items copied correctly
- [ ] Duplicate conversion blocked
- [ ] Integration tests pass
- [ ] Performance: P95 ≤ 2s verified

## References
- [ADR-011: Story-Driven Development](../../adrs/011-story-driven-development.md)
