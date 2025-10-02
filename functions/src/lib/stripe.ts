/**
 * Stripe Integration Helpers for Sierra Painting
 * 
 * PURPOSE:
 * Optional Stripe payment integration for card payments.
 * This module is ONLY used when the `payments.stripeEnabled` feature flag is TRUE.
 * 
 * RESPONSIBILITIES:
 * - Create Stripe Checkout sessions for invoice payments
 * - Verify Stripe webhook signatures
 * - Handle Stripe webhook events (payment_intent.succeeded)
 * - Sync payment status with Firestore
 * 
 * PUBLIC API:
 * - createStripeCheckoutSession(invoice): Promise<{ url: string }>
 * - verifyStripeWebhookSignature(payload, signature): Stripe.Event
 * - handlePaymentIntentSucceeded(paymentIntent): Promise<void>
 * 
 * SECURITY CONSIDERATIONS:
 * - ALWAYS verify webhook signatures (prevents spoofing)
 * - Use Stripe API keys from Secret Manager (not .env)
 * - Never trust client-provided amounts (use server-side invoice data)
 * - Idempotent webhook handling (event.id deduplication)
 * 
 * PERFORMANCE NOTES:
 * - Stripe API calls are ~200-500ms
 * - Webhook verification is fast (~5ms)
 * - Use Stripe-provided idempotency keys for API calls
 * 
 * INVARIANTS:
 * - Checkout session amounts MUST match invoice totals
 * - Webhook events MUST be idempotent (no duplicate processing)
 * - Payment status MUST be synced to Firestore after successful charge
 * 
 * USAGE EXAMPLE:
 * ```typescript
 * if (featureFlags.stripeEnabled) {
 *   const session = await createStripeCheckoutSession(invoice);
 *   return { checkoutUrl: session.url };
 * } else {
 *   throw new functions.https.HttpsError('unavailable', 'Stripe payments disabled');
 * }
 * ```
 * 
 * TODO:
 * - Add support for Stripe Payment Links (simpler alternative)
 * - Implement refund handling
 * - Add webhook event logging to BigQuery
 * - Support multiple payment methods (ACH, etc.)
 * - Add Stripe Connect for multi-tenant (if needed)
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import Stripe from 'stripe';

// Import db from index for Firestore access
// Note: admin is imported here but db is imported from index to ensure same instance
import {db} from '../index';

// ============================================================
// CONSTANTS
// ============================================================

/**
 * Stripe API version
 * Update when upgrading Stripe SDK
 */
const STRIPE_API_VERSION = '2024-06-20' as const;

/**
 * Environment variables for Stripe
 * In production, use Secret Manager
 */
const STRIPE_SECRET_KEY = process.env.STRIPE_SECRET_KEY || '';
const STRIPE_WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET || '';

// ============================================================
// INITIALIZATION
// ============================================================

/**
 * Stripe client instance
 * Lazy initialization to avoid errors when Stripe is disabled
 */
let stripeClient: Stripe | null = null;

/**
 * Get Stripe client (lazy initialization)
 */
function getStripeClient(): Stripe {
  if (!stripeClient) {
    if (!STRIPE_SECRET_KEY) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Stripe secret key not configured'
      );
    }

    stripeClient = new Stripe(STRIPE_SECRET_KEY, {
      apiVersion: STRIPE_API_VERSION,
      typescript: true,
    });
  }

  return stripeClient;
}

// ============================================================
// TYPES
// ============================================================

/**
 * Invoice data required for Stripe Checkout
 */
export interface StripeInvoiceData {
  id: string;
  total: number; // in cents
  customerEmail: string;
  customerName: string;
  lineItems: Array<{
    description: string;
    quantity: number;
    unitPrice: number; // in cents
  }>;
}

/**
 * Checkout session result
 */
export interface CheckoutSessionResult {
  url: string;
  sessionId: string;
}

// ============================================================
// PUBLIC API
// ============================================================

/**
 * Create a Stripe Checkout session for invoice payment
 * 
 * @param invoice - Invoice data
 * @param successUrl - Redirect URL on success
 * @param cancelUrl - Redirect URL on cancel
 * @returns Checkout session URL and ID
 * 
 * @example
 * const session = await createStripeCheckoutSession(invoice, successUrl, cancelUrl);
 * return { checkoutUrl: session.url };
 */
export async function createStripeCheckoutSession(
  invoice: StripeInvoiceData,
  successUrl: string,
  cancelUrl: string
): Promise<CheckoutSessionResult> {
  const stripe = getStripeClient();

  try {
    // Convert line items to Stripe format
    const lineItems = invoice.lineItems.map((item) => ({
      price_data: {
        currency: 'usd',
        product_data: {
          name: item.description,
        },
        unit_amount: item.unitPrice,
      },
      quantity: item.quantity,
    }));

    // Create checkout session
    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      payment_method_types: ['card'],
      line_items: lineItems,
      customer_email: invoice.customerEmail,
      client_reference_id: invoice.id, // Link back to invoice
      success_url: successUrl,
      cancel_url: cancelUrl,
      metadata: {
        invoiceId: invoice.id,
        source: 'sierra_painting',
      },
    });

    functions.logger.info('Stripe checkout session created', {
      sessionId: session.id,
      invoiceId: invoice.id,
      amount: invoice.total,
    });

    return {
      url: session.url!,
      sessionId: session.id,
    };
  } catch (error) {
    functions.logger.error('Failed to create Stripe checkout session', {
      invoiceId: invoice.id,
      error,
    });
    throw new functions.https.HttpsError(
      'internal',
      'Failed to create checkout session'
    );
  }
}

/**
 * Verify Stripe webhook signature
 * 
 * SECURITY: Always verify webhooks to prevent spoofing attacks.
 * 
 * @param payload - Raw request body (Buffer)
 * @param signature - Stripe-Signature header
 * @returns Verified Stripe event
 * @throws Error if signature is invalid
 * 
 * @example
 * const event = verifyStripeWebhookSignature(req.rawBody, req.headers['stripe-signature']);
 */
export function verifyStripeWebhookSignature(
  payload: Buffer | string,
  signature: string
): Stripe.Event {
  const stripe = getStripeClient();

  if (!STRIPE_WEBHOOK_SECRET) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Stripe webhook secret not configured'
    );
  }

  try {
    const event = stripe.webhooks.constructEvent(
      payload,
      signature,
      STRIPE_WEBHOOK_SECRET
    );

    functions.logger.info('Stripe webhook verified', {
      eventId: event.id,
      eventType: event.type,
    });

    return event;
  } catch (error) {
    functions.logger.error('Stripe webhook verification failed', { error });
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Invalid webhook signature'
    );
  }
}

/**
 * Handle Stripe payment_intent.succeeded event
 * 
 * Called from webhook handler after signature verification and idempotency check.
 * Marks the invoice as paid in Firestore.
 * 
 * @param paymentIntent - Stripe PaymentIntent object
 * @returns Promise<void>
 * 
 * @example
 * if (event.type === 'payment_intent.succeeded') {
 *   await handlePaymentIntentSucceeded(event.data.object);
 * }
 */
export async function handlePaymentIntentSucceeded(
  paymentIntent: Stripe.PaymentIntent
): Promise<void> {
  // Extract invoice ID from metadata
  const invoiceId = paymentIntent.metadata?.invoiceId;

  if (!invoiceId) {
    functions.logger.warn('PaymentIntent missing invoiceId in metadata', {
      paymentIntentId: paymentIntent.id,
    });
    return;
  }

  // Mark invoice as paid via Stripe
  await db.collection('invoices').doc(invoiceId).update({
    status: 'paid',
    paidAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  functions.logger.info('Payment intent succeeded', {
    paymentIntentId: paymentIntent.id,
    invoiceId,
    amount: paymentIntent.amount,
  });

  // Implementation note:
  // Instead of duplicating logic, import and call markPaidManual:
  // await markPaidManual({
  //   invoiceId,
  //   amount: paymentIntent.amount,
  //   paymentMethod: 'stripe',
  //   stripePaymentIntentId: paymentIntent.id,
  // });
}

/**
 * Retrieve a Stripe Checkout session by ID
 * 
 * @param sessionId - Stripe Checkout session ID
 * @returns Stripe session object
 * 
 * @example
 * const session = await getCheckoutSession(sessionId);
 */
export async function getCheckoutSession(
  sessionId: string
): Promise<Stripe.Checkout.Session> {
  const stripe = getStripeClient();

  try {
    const session = await stripe.checkout.sessions.retrieve(sessionId);
    return session;
  } catch (error) {
    functions.logger.error('Failed to retrieve checkout session', {
      sessionId,
      error,
    });
    throw new functions.https.HttpsError(
      'not-found',
      'Checkout session not found'
    );
  }
}

/**
 * Check if Stripe is enabled via environment variable
 * 
 * @returns true if Stripe is configured and enabled
 * 
 * @example
 * if (!isStripeEnabled()) {
 *   throw new functions.https.HttpsError('unavailable', 'Stripe payments disabled');
 * }
 */
export function isStripeEnabled(): boolean {
  return !!STRIPE_SECRET_KEY && !!STRIPE_WEBHOOK_SECRET;
}

// ============================================================
// EXPORTS
// ============================================================

export default {
  createStripeCheckoutSession,
  verifyStripeWebhookSignature,
  handlePaymentIntentSucceeded,
  getCheckoutSession,
  isStripeEnabled,
};
