import { onRequest } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';
import type { Request, Response } from 'express';
import * as admin from 'firebase-admin';
import type { Stripe } from 'stripe';
import { getStripe } from '../lib/stripe';

// Ensure Admin initialized
try { admin.app(); } catch { admin.initializeApp(); }

const STRIPE_WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET;

export const stripeWebhook = onRequest(
  {
    // If you store the secret in Secret Manager, add: secrets: ['STRIPE_WEBHOOK_SECRET'],
    region: 'us-central1',
  },
  async (req: Request, res: Response) => {
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

  let event: Stripe.Event;
    try {
      // In Cloud Functions, raw body is exposed as Buffer on req.rawBody
      const raw = (req as any).rawBody as Buffer;
      event = stripe.webhooks.constructEvent(raw, sig, STRIPE_WEBHOOK_SECRET);
    } catch (err) {
      logger.warn('Invalid Stripe signature', { message: (err as Error).message });
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
    } catch (err) {
      logger.error('Webhook handler failed', { message: (err as Error).message });
      res.status(500).send('Webhook error');
    }
  }
);
