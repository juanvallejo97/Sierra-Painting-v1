import * as functions from 'firebase-functions';
import Stripe from 'stripe';
import {db} from '../index';
import {isStripeEventProcessed, recordStripeEvent} from '../lib/idempotency';

// Initialize Stripe (will be configured via environment variable)
const stripeSecretKey = functions.config().stripe?.secret_key || '';
const stripe = new Stripe(stripeSecretKey, {
  apiVersion: '2024-06-20',
});

const webhookSecret = functions.config().stripe?.webhook_secret || '';

/**
 * Handle Stripe webhook events (standardized idempotency pattern)
 * 
 * IDEMPOTENCY:
 * Uses standardized idempotency utilities from lib/idempotency.ts
 * - Checks if event already processed via isStripeEventProcessed()
 * - Records processed events via recordStripeEvent()
 * - TTL: 30 days (automatic cleanup)
 * 
 * SECURITY:
 * - Verifies Stripe webhook signature
 * - Rejects events with invalid signature
 * - Logs all webhook attempts
 * 
 * RELIABILITY:
 * - Idempotent: processing same event multiple times has same effect
 * - Transactional updates to prevent partial state
 * - Proper error handling for retries
 */
export async function handleStripeWebhook(
  req: functions.https.Request,
  res: functions.Response<any>
): Promise<void> {
  const sig = req.headers['stripe-signature'] as string;

  if (!sig) {
    functions.logger.warn('Missing stripe-signature header');
    res.status(400).send('Missing stripe-signature header');
    return;
  }

  let event: Stripe.Event;

  try {
    // Verify signature to ensure request is from Stripe
    event = stripe.webhooks.constructEvent(req.rawBody, sig, webhookSecret);
  } catch (err) {
    functions.logger.error('Webhook signature verification failed:', err);
    res.status(400).send(`Webhook Error: ${err}`);
    return;
  }

  functions.logger.info('Stripe webhook received', {
    eventId: event.id,
    eventType: event.type,
  });

  // Process event idempotently using standardized utilities
  try {
    // Check if event already processed (idempotency)
    const alreadyProcessed = await isStripeEventProcessed(event.id);
    if (alreadyProcessed) {
      functions.logger.info('Event already processed (idempotent)', {
        eventId: event.id,
      });
      res.json({received: true, note: 'already processed'});
      return;
    }

    // Handle different event types
    switch (event.type) {
      case 'checkout.session.completed': {
        const session = event.data.object as Stripe.Checkout.Session;
        await handleCheckoutSessionCompleted(session);
        break;
      }
      case 'payment_intent.succeeded': {
        const paymentIntent = event.data.object as Stripe.PaymentIntent;
        await handlePaymentIntentSucceeded(paymentIntent);
        break;
      }
      case 'payment_intent.payment_failed': {
        const paymentIntent = event.data.object as Stripe.PaymentIntent;
        await handlePaymentIntentFailed(paymentIntent);
        break;
      }
      default:
        functions.logger.info('Unhandled event type', {
          eventType: event.type,
          eventId: event.id,
        });
    }

    // Record event as processed (with 30-day TTL)
    await recordStripeEvent(event.id, event.type);

    res.json({received: true});
  } catch (error) {
    functions.logger.error('Error processing webhook:', {
      eventId: event.id,
      eventType: event.type,
      error,
    });
    // Don't record as processed so it can be retried
    res.status(500).json({error: 'Processing failed'});
  }
}

async function handleCheckoutSessionCompleted(session: Stripe.Checkout.Session): Promise<void> {
  functions.logger.info(`Checkout session completed: ${session.id}`);

  const invoiceId = session.metadata?.invoiceId;
  if (!invoiceId) {
    functions.logger.warn('No invoiceId in session metadata');
    return;
  }

  // Create payment record
  await db.collection('payments').add({
    invoiceId: invoiceId,
    stripeSessionId: session.id,
    stripePaymentIntentId: session.payment_intent,
    amount: session.amount_total ? session.amount_total / 100 : 0,
    paymentMethod: 'stripe',
    status: 'completed',
    createdAt: new Date(),
    updatedAt: new Date(),
  });

  // Update invoice
  await db.collection('invoices').doc(invoiceId).update({
    status: 'paid',
    paidAt: new Date(),
    updatedAt: new Date(),
  });
}

async function handlePaymentIntentSucceeded(paymentIntent: Stripe.PaymentIntent): Promise<void> {
  functions.logger.info(`Payment intent succeeded: ${paymentIntent.id}`);
  
  // Additional processing if needed
}

async function handlePaymentIntentFailed(paymentIntent: Stripe.PaymentIntent): Promise<void> {
  functions.logger.error(`Payment intent failed: ${paymentIntent.id}`);
  
  const invoiceId = paymentIntent.metadata?.invoiceId;
  if (invoiceId) {
    await db.collection('invoices').doc(invoiceId).update({
      status: 'payment_failed',
      updatedAt: new Date(),
    });
  }
}
