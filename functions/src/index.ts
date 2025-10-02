import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import {z} from 'zod';
import {handleStripeWebhook} from './stripe/webhookHandler';
import {
  TimeInSchema,
  ManualPaymentSchema,
} from './schemas';

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
      role: 'crew', // Default role (changed from 'user' to match story A2)
      orgId: null,   // Set by admin via setRole
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
 * B1: Clock-in (offline + GPS + idempotent)
 * 
 * Accepts clock-in from authenticated users with:
 * - Offline queue support via clientId
 * - GPS location (optional)
 * - Idempotent via clientId
 * - Prevents duplicate open entries
 */
export const clockIn = functions
  .runWith({
    enforceAppCheck: true,  // A5: App Check required
  })
  .https.onCall(async (data, context) => {
    // 1. Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    try {
      // 2. Validate input
      const validated = TimeInSchema.parse(data);
      
      // 3. Check idempotency (prevent duplicate from offline queue)
      const idempotencyKey = `clock_in:${validated.jobId}:${validated.clientId}`;
      const idempotencyDocRef = db.collection('idempotency').doc(idempotencyKey);
      const idempotencyDoc = await idempotencyDocRef.get();
      
      if (idempotencyDoc.exists) {
        functions.logger.info(`Idempotent clock-in request: ${idempotencyKey}`);
        return idempotencyDoc.data()?.result;
      }
      
      // 4. Get user profile for orgId
      const userDoc = await db.collection('users').doc(context.auth.uid).get();
      if (!userDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'User profile not found');
      }
      const userOrgId = userDoc.data()?.orgId;
      
      // 5. Verify job exists and user is assigned
      const jobDoc = await db.collection('jobs').doc(validated.jobId).get();
      if (!jobDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Job not found');
      }
      
      const jobData = jobDoc.data();
      if (jobData?.orgId !== userOrgId) {
        throw new functions.https.HttpsError('permission-denied', 'Job not in your organization');
      }
      
      if (!jobData?.crewIds?.includes(context.auth.uid)) {
        throw new functions.https.HttpsError('permission-denied', 'Not assigned to this job');
      }
      
      // 6. Check for existing open entry (prevent overlap)
      const openEntries = await db.collectionGroup('timeEntries')
        .where('userId', '==', context.auth.uid)
        .where('jobId', '==', validated.jobId)
        .where('clockOut', '==', null)
        .limit(1)
        .get();
      
      if (!openEntries.empty) {
        functions.logger.warn('Clock-in overlap blocked', {
          userId: context.auth.uid,
          jobId: validated.jobId,
          existingEntryId: openEntries.docs[0].id,
        });
        throw new functions.https.HttpsError(
          'failed-precondition',
          'You have an open shift for this job'
        );
      }
      
      // 7. Create time entry
      const entryRef = await db.collection('jobs').doc(validated.jobId)
        .collection('timeEntries').add({
          orgId: userOrgId,
          userId: context.auth.uid,
          jobId: validated.jobId,
          clockIn: validated.at,
          clockOut: null,
          geo: validated.geo || null,
          gpsMissing: !validated.geo,
          clientId: validated.clientId,
          source: 'mobile',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      
      // 8. Create audit log entry
      await db.collection('activity_logs').add({
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        entity: 'time_entry',
        action: 'TIME_IN',
        actorUid: context.auth.uid,
        orgId: userOrgId,
        details: {
          jobId: validated.jobId,
          entryId: entryRef.id,
          hasGeo: !!validated.geo,
          source: 'mobile',
        },
      });
      
      // 9. Store idempotency record (48-hour TTL)
      const result = { success: true, entryId: entryRef.id };
      await idempotencyDocRef.set({
        key: idempotencyKey,
        operation: 'clock_in',
        resourceId: entryRef.id,
        result,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromDate(
          new Date(Date.now() + 48 * 60 * 60 * 1000)
        ),
      });
      
      // 10. Log telemetry
      functions.logger.info('Clock-in success', {
        userId: context.auth.uid,
        jobId: validated.jobId,
        hasGeo: !!validated.geo,
        entryId: entryRef.id,
      });
      
      return result;
    } catch (error) {
      if (error instanceof z.ZodError) {
        throw new functions.https.HttpsError('invalid-argument', error.message);
      }
      throw error;
    }
  });

/**
 * C3: Mark payment as paid (Manual payment - check/cash)
 * Only callable by admins
 * Idempotent via idempotency key
 */
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
    const validatedData = ManualPaymentSchema.parse(data);
    
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
    
    // Get invoice to get amount
    const invoiceDoc = await db.collection('invoices').doc(validatedData.invoiceId).get();
    if (!invoiceDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Invoice not found');
    }
    
    const invoiceData = invoiceDoc.data();
    if (invoiceData?.paid) {
      throw new functions.https.HttpsError('failed-precondition', 'Invoice already paid');
    }

    // Create payment record with audit trail
    const paymentRef = await db.collection('payments').add({
      invoiceId: validatedData.invoiceId,
      amount: invoiceData?.total || 0,
      paymentMethod: validatedData.method,
      reference: validatedData.reference || null,
      status: 'completed',
      notes: validatedData.note,
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
        amount: invoiceData?.total || 0,
        paymentMethod: validatedData.method,
        reference: validatedData.reference,
      },
    });
    
    // Create activity log entry
    await db.collection('activity_logs').add({
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      entity: 'invoice',
      action: 'INVOICE_MARK_PAID_MANUAL',
      actorUid: context.auth.uid,
      orgId: invoiceData?.orgId || null,
      details: {
        invoiceId: validatedData.invoiceId,
        paymentId: paymentRef.id,
        amount: invoiceData?.total || 0,
        method: validatedData.method,
        reference: validatedData.reference,
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
    throw error;
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
