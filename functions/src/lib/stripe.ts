import Stripe from 'stripe';

export const STRIPE_API_VERSION: Stripe.LatestApiVersion = '2025-09-30.clover';

let _stripe: Stripe | undefined;

/** Singleton Stripe client */
export function getStripe(): Stripe {
  if (!_stripe) {
    const secret = process.env.STRIPE_SECRET_KEY;
    if (!secret) {
      throw new Error('STRIPE_SECRET_KEY env var is not set');
    }
    _stripe = new Stripe(secret, { apiVersion: STRIPE_API_VERSION });
  }
  return _stripe;
}
