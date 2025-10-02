/**
 * Cloud Functions Entry Point for Sierra Painting
 * 
 * PURPOSE:
 * Central export file for all Cloud Functions.
 * Initializes Firebase Admin SDK and exports function endpoints.
 * 
 * RESPONSIBILITIES:
 * - Initialize Firebase Admin SDK
 * - Export all Cloud Functions (callable, HTTP, triggers)
 * - Provide shared DB and Auth instances
 * 
 * FUNCTION EXPORTS:
 * - createLead: Callable function for lead form submission
 * - createEstimatePdf: Callable function for PDF generation (TODO)
 * - markPaidManual: Callable function for manual payments (primary path)
 * - createCheckoutSession: Callable function for Stripe checkout (optional)
 * - stripeWebhook: HTTP function for Stripe webhook (optional)
 * - onUserCreate: Auth trigger for user profile creation
 * - onUserDelete: Auth trigger for user profile cleanup
 * 
 * ARCHITECTURE NOTES:
 * - Functions are organized by domain (leads/, payments/, pdf/)
 * - Shared utilities in lib/ (schemas, audit, idempotency, stripe)
 * - Each function file has comprehensive header comments
 * 
 * SECURITY:
 * - App Check enforced on callable functions (optional, configured per function)
 * - Admin role checks for sensitive operations
 * - Stripe webhook signature verification
 * 
 * TODO:
 * - Add scheduled functions (cleanup, notifications)
 * - Add Firestore triggers (onInvoiceCreate, etc.)
 * - Add Pub/Sub functions for async processing
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Initialize Firebase Admin SDK
admin.initializeApp();

// Export shared instances for use in other modules
export const db = admin.firestore();
export const auth = admin.auth();

// ============================================================
// LEAD FUNCTIONS
// ============================================================

export {createLead} from './leads/createLead';

// ============================================================
// PAYMENT FUNCTIONS
// ============================================================

export {markPaidManual} from './payments/markPaidManual';

// TODO: Uncomment when implemented
// export {createCheckoutSession} from './payments/createCheckoutSession';
// export {stripeWebhook} from './payments/stripeWebhook';

// ============================================================
// PDF FUNCTIONS
// ============================================================

// TODO: Migrate from services/pdf-service.ts to pdf/createEstimatePdf.ts
// export {createEstimatePdf} from './pdf/createEstimatePdf';

// ============================================================
// AUTH TRIGGERS
// ============================================================

/**
 * Create user profile on authentication
 * 
 * Triggered when a new user signs up via Firebase Auth.
 * Creates a corresponding user document in Firestore with default role.
 */
export const onUserCreate = functions.auth.user().onCreate(async (user) => {
  try {
    await db.collection('users').doc(user.uid).set({
      uid: user.uid,
      email: user.email,
      displayName: user.displayName || null,
      photoURL: user.photoURL || null,
      role: 'customer', // Default role (can be upgraded to admin/crew)
      orgId: 'default', // TODO: Implement org assignment logic
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    functions.logger.info('User profile created', {uid: user.uid, email: user.email});
  } catch (error) {
    functions.logger.error('Error creating user profile', {uid: user.uid, error});
    throw error;
  }
});

/**
 * Clean up user data on account deletion
 * 
 * Triggered when a user account is deleted from Firebase Auth.
 * Deletes the corresponding user document from Firestore.
 * 
 * TODO: Implement cascading deletes for user-related data (time entries, etc.)
 */
export const onUserDelete = functions.auth.user().onDelete(async (user) => {
  try {
    // Delete user profile
    await db.collection('users').doc(user.uid).delete();
    
    // TODO: Delete or anonymize related data:
    // - Time entries (anonymize userId)
    // - Audit logs (keep for compliance, but anonymize)
    // - Payments (keep for accounting)

    functions.logger.info('User data deleted', {uid: user.uid});
  } catch (error) {
    functions.logger.error('Error deleting user data', {uid: user.uid, error});
    throw error;
  }
});

// ============================================================
// LEGACY FUNCTIONS (TO BE MIGRATED)
// ============================================================

/**
 * Stripe webhook handler (legacy)
 * 
 * TODO: Migrate to payments/stripeWebhook.ts with proper structure
 */
import {handleStripeWebhook} from './stripe/webhookHandler';

export const stripeWebhook = functions.https.onRequest(async (req, res) => {
  try {
    await handleStripeWebhook(req, res);
  } catch (error) {
    functions.logger.error('Stripe webhook error', error);
    res.status(500).json({error: 'Webhook handler failed'});
  }
});

/**
 * Health check endpoint
 */
export const healthCheck = functions.https.onRequest((req, res) => {
  res.status(200).json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    version: '2.0.0-refactor',
  });
});

/**
 * Legacy markPaymentPaid (to be deprecated in favor of markPaidManual)
 * 
 * TODO: Remove after migrating all clients to markPaidManual
 * This is kept for backward compatibility during transition period.
 */
import {z} from 'zod';

const markPaymentPaidSchema = z.object({
  invoiceId: z.string().min(1),
  amount: z.number().positive(),
  paymentMethod: z.enum(['check', 'cash']),
  notes: z.string().optional(),
  idempotencyKey: z.string().optional(),
});

export const markPaymentPaid = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  // Verify admin role
  const userDoc = await db.collection('users').doc(context.auth.uid).get();
  if (!userDoc.exists || userDoc.data()?.role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'User must be an admin');
  }

  // Validate input
  try {
    const validatedData = markPaymentPaidSchema.parse(data);
    
    // Generate idempotency key if not provided
    const idempotencyKey = validatedData.idempotencyKey || 
                          `markPaid:${validatedData.invoiceId}:${Date.now()}`;
    const idempotencyDocRef = db.collection('idempotency').doc(idempotencyKey);
    
    // Check if this operation was already processed
    const idempotencyDoc = await idempotencyDocRef.get();
    if (idempotencyDoc.exists) {
      functions.logger.info('Idempotent request detected', {idempotencyKey});
      const storedResult = idempotencyDoc.data()?.result as {success: boolean; paymentId: string};
      return storedResult;
    }

    // Create payment record
    const paymentRef = await db.collection('payments').add({
      invoiceId: validatedData.invoiceId,
      amount: validatedData.amount,
      paymentMethod: validatedData.paymentMethod,
      status: 'completed',
      notes: validatedData.notes || null,
      markedBy: context.auth.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Add audit log entry
    await paymentRef.collection('audit').add({
      action: 'payment_marked_paid',
      performedBy: context.auth.uid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      details: {
        amount: validatedData.amount,
        paymentMethod: validatedData.paymentMethod,
      },
    });

    // Update invoice status
    await db.collection('invoices').doc(validatedData.invoiceId).update({
      status: 'paid',
      paid: true,
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    functions.logger.info('Payment marked as paid', {paymentId: paymentRef.id});
    
    const result = {
      success: true,
      paymentId: paymentRef.id,
    };
    
    // Store idempotency record
    await idempotencyDocRef.set({
      result,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      invoiceId: validatedData.invoiceId,
    });
    
    return result;
  } catch (error) {
    if (error instanceof z.ZodError) {
      throw new functions.https.HttpsError('invalid-argument', error.message);
    }
    functions.logger.error('Error marking payment as paid', error);
    throw new functions.https.HttpsError('internal', 'An error occurred');
  }
});
