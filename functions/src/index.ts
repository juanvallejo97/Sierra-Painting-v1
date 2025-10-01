import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {
  leadSchema,
  estimateSchema,
  markPaidManualSchema,
  stripeCheckoutSchema,
} from "./schemas";
import {createPdfService} from "./services/pdf-service";

admin.initializeApp();

// Create Lead Function
export const createLead = functions.https.onCall(async (data, context) => {
  // Validate authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }

  // Validate input with Zod
  const validationResult = leadSchema.safeParse(data);
  if (!validationResult.success) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      validationResult.error.message
    );
  }

  const leadData = {
    ...validationResult.data,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: context.auth.uid,
    status: "new",
  };

  try {
    const leadRef = await admin.firestore().collection("leads").add(leadData);
    return {success: true, leadId: leadRef.id};
  } catch (error) {
    console.error("Error creating lead:", error);
    throw new functions.https.HttpsError("internal", "Failed to create lead");
  }
});

// Create Estimate PDF Function
export const createEstimatePdf = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const validationResult = estimateSchema.safeParse(data);
    if (!validationResult.success) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        validationResult.error.message
      );
    }

    try {
      const pdfBuffer = await createPdfService(validationResult.data);
      const bucket = admin.storage().bucket();
      const fileName = `estimates/${data.leadId}_${Date.now()}.pdf`;
      const file = bucket.file(fileName);

      await file.save(pdfBuffer, {
        metadata: {
          contentType: "application/pdf",
        },
      });

      const [url] = await file.getSignedUrl({
        action: "read",
        expires: Date.now() + 7 * 24 * 60 * 60 * 1000, // 7 days
      });

      // Save estimate to Firestore
      const estimateRef = await admin.firestore()
        .collection("estimates")
        .add({
          ...validationResult.data,
          pdfUrl: url,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: context.auth.uid,
        });

      return {success: true, estimateId: estimateRef.id, pdfUrl: url};
    } catch (error) {
      console.error("Error creating estimate PDF:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to create estimate PDF"
      );
    }
  }
);

// Mark Invoice as Paid Manually (Check/Cash)
export const markPaidManual = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    // Check admin role
    const userDoc = await admin.firestore()
      .collection("users")
      .doc(context.auth.uid)
      .get();

    if (!userDoc.exists || !userDoc.data()?.isAdmin) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only admins can mark invoices as paid"
      );
    }

    const validationResult = markPaidManualSchema.safeParse(data);
    if (!validationResult.success) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        validationResult.error.message
      );
    }

    try {
      const {invoiceId, ...paymentData} = validationResult.data;

      // Create audit trail
      const auditData = {
        invoiceId,
        action: "manual_payment",
        paymentData,
        performedBy: context.auth.uid,
        performedAt: admin.firestore.FieldValue.serverTimestamp(),
        ipAddress: context.rawRequest.ip,
      };

      await admin.firestore().runTransaction(async (transaction) => {
        const invoiceRef = admin.firestore()
          .collection("invoices")
          .doc(invoiceId);
        const auditRef = admin.firestore()
          .collection("audit_logs")
          .doc();

        const invoice = await transaction.get(invoiceRef);
        if (!invoice.exists) {
          throw new functions.https.HttpsError(
            "not-found",
            "Invoice not found"
          );
        }

        transaction.update(invoiceRef, {
          paid: true,
          paidAt: admin.firestore.FieldValue.serverTimestamp(),
          paymentMethod: paymentData.paymentMethod,
          paymentAmount: paymentData.amount,
          checkNumber: paymentData.checkNumber,
          paymentNotes: paymentData.notes,
        });

        transaction.set(auditRef, auditData);
      });

      return {success: true};
    } catch (error) {
      console.error("Error marking invoice as paid:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to mark invoice as paid"
      );
    }
  }
);

// Optional: Stripe Checkout Session
export const createCheckoutSession = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const validationResult = stripeCheckoutSchema.safeParse(data);
    if (!validationResult.success) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        validationResult.error.message
      );
    }

    // Placeholder for Stripe integration
    // const stripe = new Stripe(functions.config().stripe.secret_key);
    // const session = await stripe.checkout.sessions.create({...});

    return {
      success: true,
      message: "Stripe integration pending - add API key",
    };
  }
);

// Optional: Stripe Webhook (Idempotent)
export const stripeWebhook = functions.https.onRequest(
  async (req, res) => {
    // Verify webhook signature
    // Handle events idempotently using event.id

    res.json({received: true});
  }
);
