# ADR-0003: Manual Payments as Primary, Stripe as Optional

**Status:** Accepted  
**Date:** 2025-01-15  
**Deciders:** Engineering Team, Business Stakeholders  
**Tags:** payments, business-logic, stripe, invoicing  
**Context:** Payment workflow must match current business practices

---

## Context and Problem Statement

The painting business currently operates primarily with manual payment methods (checks and cash). Most customers are:
- Homeowners who prefer traditional payment methods
- Commercial clients who pay via check
- Walk-in customers paying cash

**Current Business Reality:**
- ~80% of payments are check/cash
- ~15% are bank transfers (recorded manually)
- ~5% are credit card (via external terminals)
- No current online payment infrastructure
- Admin needs to manually mark invoices as paid

**Requirements:**
- Support current manual payment workflow
- Enable future online payments without major refactoring
- Maintain audit trail for all payment methods
- Prevent unauthorized payment marking
- Allow Stripe integration when business is ready

## Decision Drivers

- Match existing business workflows
- Minimize disruption to current processes
- Low upfront cost (no payment processing fees unless needed)
- Flexibility to add online payments later
- Security and fraud prevention
- Regulatory compliance (audit trails)

## Considered Options

1. **Manual payments primary, Stripe optional** (**selected**)
2. Stripe-only with manual payment recording
3. Hybrid: both methods treated equally from start

---

## Decision Outcome

**Chosen option:** **Manual payments as primary path, Stripe as optional feature**

### Implementation Strategy

**Manual Payment Flow:**
1. Customer pays via check/cash in person
2. Admin receives payment (physical check or cash)
3. Admin opens invoice in app
4. Admin taps "Mark as Paid" button
5. Admin enters payment details:
   - Payment method (check/cash)
   - Check number (if applicable)
   - Amount received
   - Payment date
   - Optional notes
6. Callable function `markPaidManual` processes payment:
   - Validates admin role
   - Checks idempotency key
   - Updates invoice: `paid: true`, `paidAt`, `paymentMethod`, `paymentAmount`
   - Creates audit log entry
   - Returns success

**Stripe Integration (Optional):**
- Behind Remote Config feature flag: `feature_stripe_enabled: false`
- When enabled:
  - "Pay Online" button appears on invoices
  - Creates Stripe Checkout session
  - Webhook processes payment confirmation
  - Auto-marks invoice as paid
- Requires setup:
  - Stripe API keys in Secret Manager
  - Webhook endpoint configured
  - Webhook signature verification

**Security:**
- Only admins can mark invoices as paid (role check)
- Firestore rules prevent clients from setting `paid: true`
- All payment operations require idempotency key
- Audit logs track who marked payment and when
- Protected fields: `paid`, `paidAt`, `paymentMethod`, `paymentAmount`

---

## Pros and Cons Summary

**Pros**
- ✅ Matches current business workflow (no retraining)
- ✅ Zero payment processing fees for manual payments
- ✅ No upfront Stripe setup required
- ✅ Can enable online payments later via feature flag
- ✅ Full audit trail for compliance
- ✅ Flexible: supports multiple payment methods

**Cons**
- ⚠️ Manual entry increases admin workload
- ⚠️ Risk of data entry errors
- ⚠️ No automatic reconciliation with bank
- ⚠️ Delayed payment recording (requires admin action)

---

## Consequences

**Positive**
1. Immediate value without payment processor integration
2. Lower operational costs (no processing fees on majority of payments)
3. Gradual adoption of online payments when ready
4. Maintained control over payment process
5. Regulatory compliance via audit logs

**Negative & Mitigations**
1. **Manual entry errors** → Input validation, confirmation dialogs
2. **Fraud risk (fake payment marking)** → Admin role enforcement, audit logs, IP logging
3. **Reconciliation overhead** → Future: bank integration, payment matching
4. **Delayed updates** → Push notifications when invoice marked paid

---

## Risks

### RISK-PAY-001: Unauthorized Payment Marking
**Severity:** Critical  
**Mitigation:**
- Strict admin role check in `markPaidManual`
- Firestore rules deny client writes to `paid` field
- Audit log every payment with admin userId
- Alert owner on large payments (>$5000)

### RISK-PAY-002: Missing Payment Records
**Severity:** High  
**Mitigation:**
- Require confirmation before marking paid
- Transaction-based updates (atomic)
- Reconciliation job (compare bank vs Firestore)
- Manual audit process monthly

### RISK-PAY-003: Refund Abuse
**Severity:** Medium  
**Mitigation:**
- Separate refund function with higher privilege
- Two-person approval for refunds >$500
- Log all refunds with reason
- Daily refund limit

---

## Implementation Notes

### Manual Payment Function

```typescript
// functions/src/payments/markPaidManual.ts
export const markPaidManual = functions.https.onCall(async (data, context) => {
  // 1. Verify admin role
  if (!context.auth || !await isAdmin(context.auth.uid)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can mark invoices as paid'
    );
  }

  // 2. Check idempotency
  const { isDuplicate, result } = await checkIdempotency(data.idempotencyKey);
  if (isDuplicate) return result;

  // 3. Validate input (Zod schema)
  const validated = ManualPaymentSchema.parse(data);

  // 4. Update invoice in transaction
  const result = await db.runTransaction(async (tx) => {
    const invoiceRef = db.collection('invoices').doc(validated.invoiceId);
    const invoice = await tx.get(invoiceRef);
    
    if (!invoice.exists) {
      throw new Error('Invoice not found');
    }
    if (invoice.data()?.paid) {
      throw new Error('Invoice already paid');
    }

    tx.update(invoiceRef, {
      paid: true,
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
      paymentMethod: validated.paymentMethod,
      paymentAmount: validated.amount,
      checkNumber: validated.checkNumber || null,
      paidBy: context.auth.uid,
      notes: validated.notes || null,
    });

    return { success: true, invoiceId: validated.invoiceId };
  });

  // 5. Create audit log
  await createAuditLog({
    action: 'payment_marked_manual',
    entity: 'invoice',
    entityId: validated.invoiceId,
    actor: context.auth.uid,
    details: {
      paymentMethod: validated.paymentMethod,
      amount: validated.amount,
      checkNumber: validated.checkNumber,
    },
  });

  // 6. Store idempotency result
  await storeIdempotencyResult(data.idempotencyKey, 'markPaidManual', result);

  return result;
});
```

### Payment Method Validation

```typescript
// functions/src/schemas/index.ts
export const ManualPaymentSchema = z.object({
  invoiceId: z.string().uuid(),
  idempotencyKey: z.string().uuid(),
  paymentMethod: z.enum(['check', 'cash', 'bank_transfer']),
  amount: z.number().positive(),
  checkNumber: z.string().optional(),
  paymentDate: z.string().datetime(),
  notes: z.string().max(500).optional(),
});
```

### Firestore Security Rules

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /invoices/{invoiceId} {
      // Clients can read invoices
      allow read: if request.auth != null;
      
      // Clients can create invoices
      allow create: if request.auth != null;
      
      // Clients can update invoices BUT cannot set payment fields
      allow update: if request.auth != null
        && !request.resource.data.keys().hasAny(['paid', 'paidAt', 'paymentMethod', 'paymentAmount', 'paidBy']);
      
      // Only admins can delete
      allow delete: if isAdmin();
    }
  }
  
  function isAdmin() {
    return request.auth != null 
      && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
  }
}
```

---

## Feature Flag Configuration

```json
{
  "feature_stripe_enabled": {
    "defaultValue": false,
    "description": "Enable Stripe online payments",
    "conditions": [
      {
        "name": "stripe_beta_testers",
        "value": true,
        "percentileRange": {
          "percentileFrom": 0,
          "percentileTo": 10
        }
      }
    ]
  }
}
```

---

## Stripe Integration (Future)

When `feature_stripe_enabled: true`:

1. **Client:**
   - Shows "Pay Online" button on invoice
   - Calls `createCheckoutSession` function
   - Redirects to Stripe Checkout

2. **Server:**
   ```typescript
   export const createCheckoutSession = functions.https.onCall(async (data, context) => {
     const invoice = await getInvoice(data.invoiceId);
     
     const session = await stripe.checkout.sessions.create({
       payment_method_types: ['card'],
       line_items: [
         {
           price_data: {
             currency: 'usd',
             product_data: { name: `Invoice #${invoice.number}` },
             unit_amount: invoice.total * 100,
           },
           quantity: 1,
         },
       ],
       mode: 'payment',
       success_url: `${domain}/invoices/${data.invoiceId}?payment=success`,
       cancel_url: `${domain}/invoices/${data.invoiceId}?payment=cancelled`,
       metadata: { invoiceId: data.invoiceId },
     });
     
     return { sessionId: session.id };
   });
   ```

3. **Webhook:**
   - Verifies Stripe signature
   - Checks event.id for idempotency
   - Marks invoice as paid
   - Creates audit log

---

## Alternatives Considered

### 1. Stripe-only with manual payment recording
**Pros:** Single payment flow  
**Cons:** Forces Stripe setup upfront, processing fees on all payments  
**Why not chosen:** Doesn't match business needs, unnecessary cost

### 2. Both methods treated equally from start
**Pros:** Flexible  
**Cons:** Over-engineering, complexity without value  
**Why not chosen:** YAGNI (You Aren't Gonna Need It)

---

## Related Decisions

- ADR-0001: Technology Stack Selection (Firebase backend)
- ADR-0006: Idempotency Strategy (prevent duplicate payments)

## References

- [Stripe Checkout Documentation](https://stripe.com/docs/payments/checkout)
- [Firebase Secret Manager](https://firebase.google.com/docs/functions/config-env#secret-manager)
- [Idempotent Payments](https://stripe.com/docs/api/idempotent_requests)

## Superseded By

None (current decision)

---

> **Note:** ADRs are immutable. Revisions require a new ADR that supersedes this one.
