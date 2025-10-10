import { onRequest } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';
import * as admin from 'firebase-admin';
import { getStripe } from '../lib/stripe';
// Ensure Admin initialized
try {
    admin.app();
}
catch {
    admin.initializeApp();
}
const STRIPE_WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET;
export const stripeWebhook = onRequest({
    // If you store the secret in Secret Manager, add: secrets: ['STRIPE_WEBHOOK_SECRET'],
    region: 'us-east4',
}, async (req, res) => {
    if (req.method !== 'POST') {
        res.set('Allow', 'POST').status(405).send('Method Not Allowed');
        return;
    }
    const stripe = getStripe();
    const sig = req.headers['stripe-signature'];
    if (!sig || Array.isArray(sig)) {
        res.status(400).send('Missing signature');
        return;
    }
    if (!STRIPE_WEBHOOK_SECRET) {
        logger.error('STRIPE_WEBHOOK_SECRET is not configured');
        res.status(500).send('Server misconfiguration');
        return;
    }
    let event;
    try {
        // In Cloud Functions, raw body is exposed as Buffer on req.rawBody
        const raw = req.rawBody;
        event = stripe.webhooks.constructEvent(raw, sig, STRIPE_WEBHOOK_SECRET);
    }
    catch (err) {
        logger.warn('Invalid Stripe signature', { message: err.message });
        res.status(400).send('Invalid signature');
        return;
    }
    try {
        switch (event.type) {
            case 'payment_intent.succeeded':
                logger.info('Payment succeeded', { id: event.id });
                break;
            case 'charge.refunded':
                logger.info('Charge refunded', { id: event.id });
                break;
            default:
                logger.info('Unhandled Stripe event', { type: event.type });
                break;
        }
        res.status(200).send({ received: true });
    }
    catch (err) {
        logger.error('Webhook handler failed', { message: err.message });
        res.status(500).send('Webhook error');
    }
});
