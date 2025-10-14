# C1: Create Quote + PDF

**Epic**: C (Invoicing) | **Priority**: P0 | **Sprint**: V2 | **Est**: L | **Risk**: M

## User Story
As an Admin, I WANT to create a quote with PDF generation, SO THAT I can send professional proposals to customers.

## Dependencies
- **A1** (Sign-in): Must be authenticated as admin

## Acceptance Criteria (BDD)

### Success Scenario: Create Quote with PDF
**GIVEN** I am signed in as an admin  
**WHEN** I create a quote with line items and customer info  
**THEN** PDF is generated within 30 seconds  
**AND** PDF is stored in Cloud Storage  
**AND** email is sent to customer with PDF attachment

### Edge Case: Large Quote
**GIVEN** I create a quote with 50+ line items  
**WHEN** PDF generation starts  
**THEN** operation completes within timeout (30s)  
**AND** all line items are rendered correctly

### Performance
- **Target**: PDF generation P95 ≤ 30 seconds
- **Metric**: Cloud Function execution time

## Data Models

### Zod Schema
```typescript
const QuoteSchema = z.object({
  customerId: z.string(),
  customerEmail: z.string().email(),
  lineItems: z.array(z.object({
    description: z.string(),
    quantity: z.number().positive(),
    rate: z.number().positive(),
  })),
});
```

### Firestore Structure
```
quotes/{quoteId}
  orgId: string
  customerId: string
  customerEmail: string
  lineItems: Array<{description, quantity, rate, amount}>
  subtotal: number
  tax: number
  total: number
  pdfUrl: string | null
  status: 'draft' | 'sent'
  createdAt: Timestamp
```

## API Contracts

### Cloud Function: `createQuote`
```typescript
export const createQuote = functions
  .runWith({ 
    enforceAppCheck: true,
    timeoutSeconds: 60,
    memory: '512MB'
  })
  .https.onCall(async (data, context) => {
    // 1. Verify admin
    // 2. Validate input
    // 3. Create quote document
    // 4. Generate PDF with pdfkit
    // 5. Upload to Cloud Storage
    // 6. Send email with SendGrid
    // 7. Return quote ID and PDF URL
  });
```

## Definition of Done (DoD)
- [ ] `createQuote` function implemented
- [ ] PDF generation working with company template
- [ ] Cloud Storage upload working
- [ ] Email sending working
- [ ] Integration tests pass
- [ ] E2E test: create quote → PDF rendered correctly
- [ ] Performance: P95 ≤ 30s verified

## Notes
- Use `pdfkit` for PDF generation
- Store PDFs in `gs://bucket/quotes/{quoteId}.pdf`
- Email via SendGrid or Firebase Extensions
- Template includes company logo, terms & conditions

## References
- [ADR-011: Story-Driven Development](../../adrs/011-story-driven-development.md)
- [pdfkit Documentation](http://pdfkit.org/)
