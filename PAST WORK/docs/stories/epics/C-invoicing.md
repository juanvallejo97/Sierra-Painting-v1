# Epic C: Invoicing

## Overview
Complete invoicing workflow from quote creation to payment tracking, including PDF generation, manual payment marking, and Stripe integration.

## Goals
- Generate professional PDF quotes and invoices
- Convert quotes to invoices seamlessly
- Track payment status (paid/unpaid)
- Support manual and Stripe payments
- Handle refunds and voids

## Stories

### V2 (Core Invoicing)
- **C1**: Create Quote + PDF (P0, L, M)
  - Admin creates quote with line items
  - Generate PDF with company branding
  - Store in Cloud Storage
  - Email to customer
  
- **C2**: Quote → Invoice (P0, M, L)
  - Convert accepted quote to invoice
  - Maintain line item details
  - Update status tracking
  
- **C3**: Manual Mark Paid (P0, M, M)
  - Admin marks invoice as paid
  - Record payment method (cash, check)
  - Create audit log entry
  - Idempotent operation

### V4 (Payment Processing)
- **C5**: Stripe Checkout (P1, L, H)
  - Generate Stripe checkout session
  - Redirect customer to payment page
  - Webhook for payment confirmation
  - Automatic mark paid
  
- **C6**: Refund/Void (P2, M, M)
  - Admin can refund paid invoice
  - Admin can void unpaid invoice
  - Stripe refund integration
  - Audit trail

### Future Enhancements
- **C4**: Recurring Invoices
- **C7**: Payment Plans
- **C8**: Late Fees

## Key Data Models

### Quote/Invoice Document
```
quotes/{quoteId}
  orgId: string
  customerId: string
  status: 'draft' | 'sent' | 'accepted' | 'declined'
  lineItems: Array<{
    description: string
    quantity: number
    rate: number
    amount: number
  }>
  subtotal: number
  tax: number
  total: number
  pdfUrl: string | null
  createdAt: Timestamp
  updatedAt: Timestamp

invoices/{invoiceId}
  orgId: string
  customerId: string
  quoteId: string | null  // If converted from quote
  status: 'draft' | 'sent' | 'paid' | 'void'
  lineItems: Array<{...}>
  subtotal: number
  tax: number
  total: number
  pdfUrl: string | null
  paymentMethod: 'cash' | 'check' | 'stripe' | null
  paidAt: Timestamp | null
  stripeSessionId: string | null
  createdAt: Timestamp
  updatedAt: Timestamp
```

## Technical Approach

### PDF Generation
- Cloud Function using `pdfkit` or similar
- Template with company logo and branding
- Store in Firebase Cloud Storage
- Signed URLs for secure access

### Payment Flow
1. Admin creates quote → PDF generated → emailed
2. Customer accepts → converted to invoice
3. Payment:
   - **Manual**: Admin marks paid with payment method
   - **Stripe**: Customer pays via checkout → webhook → auto mark paid

### Idempotency
- Use `clientId` for manual mark paid
- Stripe uses `idempotency_key` automatically
- Prevent duplicate payment recording

## Success Metrics
- Quote generation latency: P95 <5s
- PDF quality: Professional, no rendering errors
- Payment tracking accuracy: 100%
- Stripe payment success rate: >98%
- Refund processing time: <24 hours

## Dependencies
- Epic A: Authentication (admin access required)
- Cloud Functions for PDF generation
- Firebase Cloud Storage for PDF hosting
- Stripe API (for C5, C6)

## References
- [ADR-006: Idempotency Strategy](../../adrs/006-idempotency-strategy.md)
- [ADR-011: Story-Driven Development](../../adrs/011-story-driven-development.md)
- [Stripe Documentation](https://stripe.com/docs)
