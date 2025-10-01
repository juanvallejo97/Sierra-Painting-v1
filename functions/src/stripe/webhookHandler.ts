import * as functions from 'firebase-functions';
import Stripe from 'stripe';
import {db} from '../index';

// Initialize Stripe (will be configured via environment variable)
const stripeSecretKey = functions.config().stripe?.secret_key || '';
const stripe = new Stripe(stripeSecretKey, {
  apiVersion: '2024-06-20',
});

const webhookSecret = functions.config().stripe?.webhook_secret || '';

/**
 * Handle Stripe webhook events
 * This handler is idempotent - processing the same event multiple times has the same effect
 */
export async function handleStripeWebhook(
  req: functions.https.Request,
  res: functions.Response<any>
): Promise<void> {
  const sig = req.headers['stripe-signature'] as string;

  if (!sig) {
    res.status(400).send('Missing stripe-signature header');
    return;
  }

  let event: Stripe.Event;

  try {
    event = stripe.webhooks.constructEvent(req.rawBody, sig, webhookSecret);
  } catch (err) {
    functions.logger.error('Webhook signature verification failed:', err);
    res.status(400).send(`Webhook Error: ${err}`);
    return;
  }

  // Process event idempotently
  try {
    // Check if event already processed (idempotency)
    const eventDoc = await db.collection('stripe_events').doc(event.id).get();
    if (eventDoc.exists) {
      functions.logger.info(`Event ${event.id} already processed`);
      res.json({received: true, note: 'already processed'});
      return;
    }

    // Mark event as being processed
    await db.collection('stripe_events').doc(event.id).set({
      type: event.type,
      processed: false,
      createdAt: new Date(event.created * 1000),
      receivedAt: new Date(),
    });

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
        functions.logger.info(`Unhandled event type: ${event.type}`);
    }

    // Mark event as processed
    await db.collection('stripe_events').doc(event.id).update({
      processed: true,
      processedAt: new Date(),
    });

    res.json({received: true});
  } catch (error) {
    functions.logger.error('Error processing webhook:', error);
    // Don't mark as processed so it can be retried
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
