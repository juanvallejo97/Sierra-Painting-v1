# C5: Stripe Checkout

**Epic**: C (Invoicing) | **Priority**: P1 | **Sprint**: V4 | **Est**: L | **Risk**: H

## User Story
As a Customer, I WANT to pay invoices with Stripe, SO THAT payment is secure and convenient.

## Acceptance Criteria

### Success Scenario
**GIVEN** I receive an invoice email  
**WHEN** I click "Pay Now"  
**THEN** I am redirected to Stripe checkout  
**AND** after payment, invoice is marked paid automatically

## Data Models

```
invoices/{invoiceId}
  stripeSessionId: string | null
  stripePaymentIntentId: string | null
  paymentMethod: 'stripe' | null
  paidAt: Timestamp | null
```

## API Contracts

```typescript
export const createStripeCheckout = functions.https.onCall(async (data, context) => {
  // 1. Get invoice
  // 2. Create Stripe checkout session
  // 3. Return session URL
});

export const stripeWebhook = functions.https.onRequest(async (req, res) => {
  // 1. Verify webhook signature
  // 2. Handle payment_intent.succeeded
  // 3. Mark invoice as paid
  // 4. Send confirmation email
});
```

## Definition of Done
- [ ] Stripe integration working
- [ ] Webhook handler implemented
- [ ] Invoice auto-marked paid
- [ ] E2E test: create checkout → pay → invoice paid

## References
- [Stripe Documentation](https://stripe.com/docs)
