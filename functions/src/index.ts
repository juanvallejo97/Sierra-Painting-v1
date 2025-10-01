import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import {z} from 'zod';
import {handleStripeWebhook} from './stripe/webhookHandler';

// Initialize Firebase Admin
admin.initializeApp();

// Export Firestore and Auth for use in other modules
export const db = admin.firestore();
export const auth = admin.auth();

/**
 * Create user profile on authentication
 */
export const onUserCreate = functions.auth.user().onCreate(async (user) => {
  try {
    await db.collection('users').doc(user.uid).set({
      email: user.email,
      displayName: user.displayName || null,
      photoURL: user.photoURL || null,
      role: 'user', // Default role
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    functions.logger.info(`Created user profile for ${user.uid}`);
  } catch (error) {
    functions.logger.error('Error creating user profile:', error);
    throw error;
  }
});

/**
 * Clean up user data on account deletion
 */
export const onUserDelete = functions.auth.user().onDelete(async (user) => {
  try {
    // Delete user profile
    await db.collection('users').doc(user.uid).delete();
    
    functions.logger.info(`Deleted user data for ${user.uid}`);
  } catch (error) {
    functions.logger.error('Error deleting user data:', error);
    throw error;
  }
});

/**
 * Mark payment as paid (Manual payment - check/cash)
 * Only callable by admins
 * Idempotent via idempotency key
 */
const markPaymentPaidSchema = z.object({
  invoiceId: z.string().min(1),
  amount: z.number().positive(),
  paymentMethod: z.enum(['check', 'cash']),
  notes: z.string().optional(),
  idempotencyKey: z.string().optional(), // Optional client-provided key for idempotency
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
    
    // Check if this operation was already processed (idempotency check)
    const idempotencyDoc = await idempotencyDocRef.get();
    if (idempotencyDoc.exists) {
      functions.logger.info(`Idempotent request detected: ${idempotencyKey}`);
      // Return the original result
      const storedResult = idempotencyDoc.data()?.result as {success: boolean; paymentId: string};
      return storedResult;
    }

    // Create payment record with audit trail
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

    // Update invoice status - set paid and paidAt fields
    await db.collection('invoices').doc(validatedData.invoiceId).update({
      status: 'paid',
      paid: true,
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    functions.logger.info(`Payment marked as paid: ${paymentRef.id}`);
    
    const result = {
      success: true,
      paymentId: paymentRef.id,
    };
    
    // Store idempotency record to prevent duplicate processing
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
    functions.logger.error('Error marking payment as paid:', error);
    throw new functions.https.HttpsError('internal', 'An error occurred');
  }
});


/**
 * Stripe webhook handler (optional, behind feature flag)
 * Must be idempotent
 */
export const stripeWebhook = functions.https.onRequest(async (req, res) => {
  try {
    await handleStripeWebhook(req, res);
  } catch (error) {
    functions.logger.error('Stripe webhook error:', error);
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
  });
});
