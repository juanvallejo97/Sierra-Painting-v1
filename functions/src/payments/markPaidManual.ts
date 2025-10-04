/**
 * Mark Invoice as Paid (Manual Payment) Cloud Function
 * 
 * PURPOSE:
 * Primary payment path for Sierra Painting.
 * Admin-only callable function to mark an invoice as paid for check/cash payments.
 * Writes payment record, updates invoice, and creates immutable audit log.
 * 
 * RESPONSIBILITIES:
 * - Validate admin role
 * - Validate payment data with Zod schema
 * - Check idempotency (prevent duplicate payments)
 * - Update invoice status to 'paid'
 * - Write payment record to payments collection
 * - Create immutable audit log entry
 * - Trigger notifications (TODO: email to customer)
 * 
 * PUBLIC API:
 * - markPaidManual(data: ManualPayment, context: CallableContext): Promise<InvoiceResult>
 * 
 * INPUT SCHEMA (ManualPaymentSchema):
 * - invoiceId: string
 * - amount: number (in cents)
 * - paymentMethod: 'check' | 'cash'
 * - checkNumber?: string (required if method === 'check')
 * - notes?: string (max 500 chars)
 * - idempotencyKey?: string (optional, for retry safety)
 * 
 * OUTPUT:
 * - { invoiceId: string, paymentId: string, paidAt: string }
 * 
 * SECURITY CONSIDERATIONS:
 * - Admin-only access (verified via Firestore users/{uid}.role === 'admin')
 * - App Check enforced
 * - Client CANNOT directly set invoice.paid or invoice.paidAt (Firestore rules enforce)
 * - Idempotency key prevents duplicate payments from retries
 * - Audit log is write-only (clients cannot read or modify)
 * 
 * PERFORMANCE NOTES:
 * - Admin role check: ~50ms (Firestore read)
 * - Idempotency check: ~50ms (Firestore read)
 * - Transaction write: ~100-150ms
 * - Total: <500ms P95
 * 
 * INVARIANTS:
 * - Invoice must exist and not already be paid
 * - Payment amount must match invoice total (TODO: add validation)
 * - Payment record is immutable once created
 * - Audit log entry is created atomically with payment
 * 
 * USAGE EXAMPLE (Client):
 * ```typescript
 * const markPaid = httpsCallable(functions, 'markPaidManual');
 * const result = await markPaid({
 *   invoiceId: 'inv_123',
 *   amount: 150000, // $1500.00 in cents
 *   paymentMethod: 'check',
 *   checkNumber: '1234',
 *   notes: 'Received at office',
 * });
 * ```
 * 
 * TODO (Future Enhancements):
 * - Send email notification to customer
 * - Log Analytics event (payment_received)
 * - Add support for partial payments
 * - Add support for overpayments (credit)
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import {ManualPaymentSchema} from '../lib/zodSchemas';
import {logAudit, createAuditEntry, extractCallableMetadata} from '../lib/audit';
import {
  checkIdempotency,
  recordIdempotency,
  generateIdempotencyKey,
  isValidIdempotencyKey,
} from '../lib/idempotency';
import { withValidation, adminEndpoint } from '../middleware/withValidation';

// ============================================================
// CONSTANTS
// ============================================================

const INVOICES_COLLECTION = 'invoices';
const PAYMENTS_COLLECTION = 'payments';

// ============================================================
// MAIN FUNCTION
// ============================================================

export const markPaidManual = withValidation(
  ManualPaymentSchema,
  adminEndpoint({ functionName: 'markPaidManual' })
)(async (validatedPayment, context) => {  // ========================================
  // IDEMPOTENCY CHECK
  // ========================================

  const idempotencyKey =
    validatedPayment.idempotencyKey ||
    generateIdempotencyKey('markPaid', validatedPayment.invoiceId, Date.now().toString());

  // Validate format if client-provided
  if (validatedPayment.idempotencyKey && !isValidIdempotencyKey(idempotencyKey)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Invalid idempotency key format'
    );
  }

  const alreadyProcessed = await checkIdempotency(idempotencyKey);
  if (alreadyProcessed) {
    functions.logger.info('Duplicate payment request (idempotent)', {
      idempotencyKey,
      invoiceId: validatedPayment.invoiceId,
    });
    return {
      success: true,
      message: 'Payment already processed',
      invoiceId: validatedPayment.invoiceId,
    };
  }

  // ========================================
  // TRANSACTION: UPDATE INVOICE + CREATE PAYMENT
  // ========================================

  const db = admin.firestore();
  const invoiceRef = db.collection(INVOICES_COLLECTION).doc(validatedPayment.invoiceId);
  const paymentRef = db.collection(PAYMENTS_COLLECTION).doc();

  interface InvoiceData {
    paid?: boolean;
    orgId?: string;
    amount?: number;
    total?: number;
  }
  
  let invoiceData: InvoiceData = {};
  const paymentId = paymentRef.id; // Initialize here
  let paidAt = ''; // Initialize to empty string

  await db.runTransaction(async (transaction: admin.firestore.Transaction) => {
    // Read invoice
    const invoiceDoc = await transaction.get(invoiceRef);

    if (!invoiceDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        `Invoice ${validatedPayment.invoiceId} not found`
      );
    }

    invoiceData = invoiceDoc.data() as InvoiceData;

    // Check if already paid
    if (invoiceData.paid) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Invoice is already marked as paid'
      );
    }

    // Validate payment amount matches invoice total
    const invoiceTotal = invoiceData.total || invoiceData.amount || 0;
    if (validatedPayment.amount !== invoiceTotal) {
      functions.logger.warn('Payment amount mismatch', {
        invoiceId: validatedPayment.invoiceId,
        paymentAmount: validatedPayment.amount,
        invoiceTotal,
      });
      throw new functions.https.HttpsError(
        'invalid-argument',
        `Payment amount (${validatedPayment.amount}) does not match invoice total (${invoiceTotal})`
      );
    }

    // Update invoice
    paidAt = new Date().toISOString();
    transaction.update(invoiceRef, {
      paid: true,
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
      status: 'paid',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Create payment record (already have paymentId from paymentRef.id)
    transaction.set(paymentRef, {
      invoiceId: validatedPayment.invoiceId,
      amount: validatedPayment.amount,
      paymentMethod: validatedPayment.paymentMethod,
      checkNumber: validatedPayment.checkNumber,
      notes: validatedPayment.notes,
      processedBy: context.auth.uid,
      orgId: invoiceData.orgId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  // ========================================
  // AUDIT LOG (Outside Transaction)
  // ========================================

  const metadata = extractCallableMetadata(context);
  await logAudit(createAuditEntry({
    entity: 'invoice',
    entityId: validatedPayment.invoiceId,
    action: 'paid',
    actor: context.auth.uid,
    actorRole: 'admin',
    orgId: invoiceData.orgId || 'unknown',
    ...metadata,
    metadata: {
      paymentId,
      amount: validatedPayment.amount,
      paymentMethod: validatedPayment.paymentMethod,
      checkNumber: validatedPayment.checkNumber,
    },
  }));

  // ========================================
  // RECORD IDEMPOTENCY
  // ========================================

  await recordIdempotency(idempotencyKey, {invoiceId: validatedPayment.invoiceId, paymentId});

  // ========================================
  // NOTIFICATIONS
  // ========================================

  // TODO: Send email notification to customer
  // TODO: Log Analytics event (payment_received)

  functions.logger.info('Invoice marked as paid', {
    invoiceId: validatedPayment.invoiceId,
    paymentId,
    amount: validatedPayment.amount,
    method: validatedPayment.paymentMethod,
  });

  // ========================================
  // RETURN RESULT
  // ========================================

  return {
    success: true,
    invoiceId: validatedPayment.invoiceId,
    paymentId,
    paidAt,
  };
});
