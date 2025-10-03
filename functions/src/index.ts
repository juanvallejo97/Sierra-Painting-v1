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
 * - stripeWebhook: HTTP function for Stripe webhook (legacy/temporary)
 * - onUserCreate: Auth trigger for user profile creation
 * - onUserDelete: Auth trigger for user profile cleanup
 *
 * ARCHITECTURE NOTES:
 * - Functions are organized by domain (leads/, payments/, pdf/)
 * - Shared utilities in lib/ (schemas, audit, idempotency, stripe)
 * - Each function file has comprehensive header comments
 *
 * SECURITY:
 * - App Check enforced on callable functions (configured per function)
 * - Admin role checks for sensitive operations
 * - Stripe webhook signature verification
 *
 * TODO:
 * - Add scheduled functions (cleanup, notifications)
 * - Add Firestore triggers (onInvoiceCreate, etc.)
 * - Add Pub/Sub functions for async processing
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { z } from "zod";

// Schemas (from schemas/)
import { TimeInSchema, ManualPaymentSchema } from "./schemas";

// Stripe webhook handler
import { handleStripeWebhook } from "./payments/stripeWebhook";

// Ops library
import { log, getOrCreateRequestId, withSpan, initializeTracer } from "./lib/ops";

// Initialize Firebase Admin SDK
admin.initializeApp();

// Initialize OpenTelemetry tracer
initializeTracer();

// Export shared instances for use in other modules
export const db = admin.firestore();
export const auth = admin.auth();

// ============================================================
// OPS FUNCTIONS
// ============================================================

export { initializeFlagsFunction as initializeFlags } from "./ops/initializeFlags";

// ============================================================
// LEAD FUNCTIONS
// ============================================================

export { createLead } from "./leads/createLead";

// ============================================================
// PAYMENT FUNCTIONS
// ============================================================

export { markPaidManual } from "./payments/markPaidManual";

// TODO: Uncomment when implemented (new structured versions)
// export { createCheckoutSession } from "./payments/createCheckoutSession";
// export { stripeWebhook as newStripeWebhook } from "./payments/stripeWebhook";

// ============================================================
// PDF FUNCTIONS
// ============================================================

// TODO: Migrate from services/pdf-service.ts to pdf/createEstimatePdf.ts
// export { createEstimatePdf } from "./pdf/createEstimatePdf";

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
    await db.collection("users").doc(user.uid).set({
      uid: user.uid,
      email: user.email,
      displayName: user.displayName || null,
      photoURL: user.photoURL || null,
      role: "crew", // Default role (matches story A2)
      orgId: null, // Set by admin via role/org assignment
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    functions.logger.info("User profile created", { uid: user.uid, email: user.email });
  } catch (error) {
    functions.logger.error("Error creating user profile", { uid: user.uid, error });
    throw error;
  }
});

/**
 * Clean up user data on account deletion
 *
 * Triggered when a user account is deleted from Firebase Auth.
 * Deletes the corresponding user document from Firestore.
 *
 * TODO: Implement cascading deletes/anonymization for related data.
 */
export const onUserDelete = functions.auth.user().onDelete(async (user) => {
  try {
    // Delete user profile
    await db.collection("users").doc(user.uid).delete();

    // TODO: Delete or anonymize related data:
    // - Time entries (anonymize userId)
    // - Audit logs (keep for compliance, but anonymize actor)
    // - Payments (keep for accounting)

    functions.logger.info("User data deleted", { uid: user.uid });
  } catch (error) {
    functions.logger.error("Error deleting user data", { uid: user.uid, error });
    throw error;
  }
});

// ============================================================
// LEGACY/TRANSITIONAL ENDPOINTS (TO BE MIGRATED)
// ============================================================

/**
 * Stripe webhook handler (legacy path)
 *
 * TODO: Replace with payments/stripeWebhook.ts after migration.
 */
export const stripeWebhook = functions.https.onRequest(async (req, res) => {
  try {
    // Cast res to expected type for webhook handler
    await handleStripeWebhook(req, res as functions.Response<{received: boolean; note?: string} | {error: string}>);
  } catch (error: unknown) {
    functions.logger.error("Stripe webhook error", error);
    res.status(500).json({ error: "Webhook handler failed" });
  }
});

/**
 * Health check endpoint
 */
export const healthCheck = functions.https.onRequest((req, res) => {
  res.status(200).json({
    status: "ok",
    timestamp: new Date().toISOString(),
    version: "2.0.0-refactor",
  });
});

// ============================================================
// B1: Clock-in (offline + GPS + idempotent)
// ============================================================

/**
 * Accepts clock-in from authenticated users with:
 * - Offline queue support via clientId
 * - Optional GPS location
 * - Idempotency via clientId
 * - Prevents duplicate open entries
 */
export const clockIn = functions
  .runWith({
    enforceAppCheck: true, // A5: App Check required
  })
  .https.onCall(async (data, context) => {
    // 1) Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
    }

    const userId = context.auth.uid;
    const requestId = getOrCreateRequestId(context.rawRequest?.headers as Record<string, string | string[]> | undefined);
    const startTime = Date.now();

    return withSpan('clockIn', async (span) => {
      const logger = log.child({ requestId, userId });
      
      span.setAttribute('userId', userId);
      
      try {
        // 2) Validate input
        const validated = TimeInSchema.parse(data);
        
        logger.info('clock_in_initiated', { 
          jobId: validated.jobId,
          hasGeo: !!validated.geo 
        });
        
        span.setAttribute('jobId', validated.jobId);

      // 3) Check idempotency (prevent duplicate from offline queue)
      const idempotencyKey = `clock_in:${validated.jobId}:${validated.clientId}`;
      const idempotencyDocRef = db.collection("idempotency").doc(idempotencyKey);
      const idempotencyDoc = await idempotencyDocRef.get();

      if (idempotencyDoc.exists) {
        logger.info('clock_in_idempotent', { idempotencyKey });
        const data = idempotencyDoc.data();
        return data?.result as Record<string, unknown>;
      }

      // 4) Get user profile for org scope
      const userDoc = await db.collection("users").doc(userId).get();
      if (!userDoc.exists) {
        throw new functions.https.HttpsError("not-found", "User profile not found");
      }
      const userData = userDoc.data();
      const userOrgId = userData?.orgId as string | undefined;
      
      // Add orgId to logger context
      const orgLogger = logger.child({ orgId: userOrgId });

      // 5) Verify job exists & assignment
      const jobDoc = await db.collection("jobs").doc(validated.jobId).get();
      if (!jobDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Job not found");
      }

      const jobData = jobDoc.data();
      if (jobData?.orgId !== userOrgId) {
        throw new functions.https.HttpsError("permission-denied", "Job not in your organization");
      }

      if (!Array.isArray(jobData?.crewIds) || !(jobData.crewIds as string[]).includes(userId)) {
        throw new functions.https.HttpsError("permission-denied", "Not assigned to this job");
      }

      // 6) Prevent overlap (no open entry for this job)
      const openEntries = await db
        .collectionGroup("timeEntries")
        .where("userId", "==", userId)
        .where("jobId", "==", validated.jobId)
        .where("clockOut", "==", null)
        .limit(1)
        .get();

      if (!openEntries.empty) {
        orgLogger.warn('clock_in_overlap_blocked', {
          jobId: validated.jobId,
          existingEntryId: openEntries.docs[0].id,
        });
        throw new functions.https.HttpsError("failed-precondition", "You have an open shift for this job");
      }

      // 7) Create time entry
      const entryRef = await db
        .collection("jobs")
        .doc(validated.jobId)
        .collection("timeEntries")
        .add({
          orgId: userOrgId,
          userId: userId,
          jobId: validated.jobId,
          clockIn: validated.at,
          clockOut: null,
          geo: validated.geo || null,
          gpsMissing: !validated.geo,
          clientId: validated.clientId,
          source: "mobile",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      // 8) Activity log
      await db.collection("activity_logs").add({
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        entity: "time_entry",
        action: "TIME_IN",
        actorUid: userId,
        orgId: userOrgId,
        details: {
          jobId: validated.jobId,
          entryId: entryRef.id,
          hasGeo: !!validated.geo,
          source: "mobile",
        },
      });

      // 9) Store idempotency record (48-hour TTL)
      const result = { success: true, entryId: entryRef.id };
      await idempotencyDocRef.set({
        key: idempotencyKey,
        operation: "clock_in",
        resourceId: entryRef.id,
        result,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 48 * 60 * 60 * 1000)),
      });

      // 10) Telemetry
      const latencyMs = Date.now() - startTime;
      orgLogger.perf('clockIn', latencyMs, {
        firestoreReads: 3,
        firestoreWrites: 3,
        hasGeo: !!validated.geo,
      });
      
      orgLogger.info('clock_in_success', {
        jobId: validated.jobId,
        hasGeo: !!validated.geo,
        entryId: entryRef.id,
      });

      return result;
    } catch (error) {
      if (error instanceof z.ZodError) {
        logger.error('clock_in_validation_error', { error: error.message });
        throw new functions.https.HttpsError("invalid-argument", error.message);
      }
      logger.error('clock_in_error', error as Error);
      throw error;
    }
    });
  });

// ============================================================
// Legacy markPaymentPaid (compat; prefer payments/markPaidManual)
// ============================================================

/**
 * C3: Mark payment as paid (Manual payment - check/cash)
 * Legacy callable maintained temporarily for backward compatibility.
 * Prefer using payments/markPaidManual.
 */
export const markPaymentPaid = functions
  .runWith({
    enforceAppCheck: true,
    consumeAppCheckToken: true, // Prevent replay attacks
  })
  .https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
  }

  const userId = context.auth.uid;
  const requestId = getOrCreateRequestId(context.rawRequest?.headers as Record<string, string | string[]> | undefined);
  const startTime = Date.now();
  
  return withSpan('markPaymentPaid', async (span) => {
    const logger = log.child({ requestId, userId });
    
    span.setAttribute('userId', userId);

    // App Check validation (defense in depth)
    if (!context.app) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "App Check validation failed"
      );
    }

    // Verify admin role
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists || userDoc.data()?.role !== "admin") {
      throw new functions.https.HttpsError("permission-denied", "User must be an admin");
    }

    try {
      // Validate input using current schema
      const validatedData = ManualPaymentSchema.parse(data);
      
      logger.info('mark_paid_initiated', {
        invoiceId: validatedData.invoiceId,
        method: validatedData.method,
      });
      
      span.setAttribute('invoiceId', validatedData.invoiceId);
      span.setAttribute('paymentMethod', validatedData.method);

    // Idempotency
    const idempotencyKey =
      validatedData.idempotencyKey || `markPaid:${validatedData.invoiceId}:${Date.now()}`;
    const idempotencyDocRef = db.collection("idempotency").doc(idempotencyKey);

    const already = await idempotencyDocRef.get();
    if (already.exists) {
      functions.logger.info("Idempotent request detected", { idempotencyKey });
      const storedResult = already.data()?.result as { success: boolean; paymentId: string };
      return storedResult;
    }

    // Fetch invoice
    const invoiceDoc = await db.collection("invoices").doc(validatedData.invoiceId).get();
    if (!invoiceDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Invoice not found");
    }

    const invoiceData = invoiceDoc.data() as {
      paid?: boolean;
      total?: number;
      amount?: number;
      orgId?: string;
    } | undefined;
    if (invoiceData?.paid) {
      throw new functions.https.HttpsError("failed-precondition", "Invoice already paid");
    }

    // Validate payment amount if provided in the request
    const invoiceTotal = invoiceData?.total ?? invoiceData?.amount ?? 0;
    if (validatedData.amount && validatedData.amount !== invoiceTotal) {
      logger.warn('payment_amount_mismatch', {
        invoiceId: validatedData.invoiceId,
        providedAmount: validatedData.amount,
        invoiceTotal,
      });
      throw new functions.https.HttpsError(
        "invalid-argument",
        `Payment amount (${validatedData.amount}) does not match invoice total (${invoiceTotal})`
      );
    }

    // Create payment record
    const paymentRef = await db.collection("payments").add({
      invoiceId: validatedData.invoiceId,
      amount: invoiceData?.total ?? 0,
      paymentMethod: validatedData.method,
      reference: validatedData.reference ?? null,
      status: "completed",
      notes: validatedData.note,
      markedBy: userId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Audit nested under payment
    await paymentRef.collection("audit").add({
      action: "payment_marked_paid",
      performedBy: userId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      details: {
        amount: invoiceData?.total ?? 0,
        paymentMethod: validatedData.method,
        reference: validatedData.reference ?? null,
        note: validatedData.note,
      },
    });

    // Activity log (collection-level)
    await db.collection("activity_logs").add({
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      entity: "invoice",
      action: "INVOICE_MARK_PAID_MANUAL",
      actorUid: userId,
      orgId: invoiceData?.orgId ?? null,
      details: {
        invoiceId: validatedData.invoiceId,
        paymentId: paymentRef.id,
        amount: invoiceData?.total ?? 0,
        method: validatedData.method,
        reference: validatedData.reference ?? null,
        note: validatedData.note,
      },
    });

    // Update invoice status
    await db.collection("invoices").doc(validatedData.invoiceId).update({
      status: "paid",
      paid: true,
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const result = { success: true, paymentId: paymentRef.id };

    // Persist idempotency
    await idempotencyDocRef.set({
      result,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      invoiceId: validatedData.invoiceId,
    });

    const latencyMs = Date.now() - startTime;
    logger.perf('markPaymentPaid', latencyMs, {
      firestoreReads: 2,
      firestoreWrites: 5,
      amount: invoiceData?.total ?? 0,
    });
    
    logger.info('payment_marked_paid', { 
      paymentId: paymentRef.id,
      invoiceId: validatedData.invoiceId,
      amount: invoiceData?.total ?? 0,
    });
    
    return result;
  } catch (error) {
    if (error instanceof z.ZodError) {
      logger.error('mark_paid_validation_error', { error: error.message });
      throw new functions.https.HttpsError("invalid-argument", error.message);
    }
    logger.error('mark_paid_error', error as Error);
    throw new functions.https.HttpsError("internal", "An error occurred");
  }
  });
});