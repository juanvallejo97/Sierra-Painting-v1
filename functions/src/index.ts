// functions/src/index.ts
/**
 * Firebase Cloud Functions — v2 modernization
 *
 * Key changes from v1 ➜ v2:
 *  - No `runWith(...)`; pass options as the first arg to each trigger.
 *  - Use specific v2 entry points: `v2/https`, `v2/auth`, …
 *  - Use `CallableRequest` instead of `CallableContext`.
 *  - Prefer `setGlobalOptions` for defaults.
 *  - Use `defineSecret` for runtime secrets (Stripe, etc.).
 *  - Use `logger` from 'firebase-functions/logger' (structured logs).
 */

import { logger } from 'firebase-functions/logger';
import {
  onRequest,
  Request,
  Response,
  onCall,
  CallableRequest,
  HttpsError,
} from 'firebase-functions/v2/https';
import { onUserCreated, onUserDeleted } from 'firebase-functions/v2/auth';
import { setGlobalOptions } from 'firebase-functions/v2/options';
import { defineSecret } from 'firebase-functions/params';

// ───────────────────────────────────────────────────────────────────────────────
// Global defaults (replaces scattered runWith({...}) from v1)
// ───────────────────────────────────────────────────────────────────────────────

setGlobalOptions({
  region: 'us-central1',
  // memory: '256MiB',            // uncomment / tune as needed
  // cpu: 1,                       // or 'g1', 'g2' if you use gen-2 scaling
  // maxInstances: 10,
  // minInstances: 0,
  // invoker: 'public',            // or restrict: ['serviceAccount:...']
});

// Secrets (v2 params API)
// Add whatever your app uses; these are examples.
export const STRIPE_SECRET = defineSecret('STRIPE_SECRET'); // e.g. live key
export const STRIPE_WEBHOOK_SECRET = defineSecret('STRIPE_WEBHOOK_SECRET');
export const STRIPE_API_VERSION = defineSecret('STRIPE_API_VERSION'); // if you pin versions

// ───────────────────────────────────────────────────────────────────────────────
// Auth triggers (v2)
// ───────────────────────────────────────────────────────────────────────────────

/**
 * User created
 * v1: functions.auth.user().onCreate(handler)
 * v2: onUserCreated(handler)
 */
export const userCreated = onUserCreated(async (event) => {
  const user = event.data; // UserRecord
  logger.info('User created', { uid: user.uid, email: user.email });

  // TODO: move/create business logic here (welcome email, profile doc, etc.)
});

/**
 * User deleted
 * v1: functions.auth.user().onDelete(handler)
 * v2: onUserDeleted(handler)
 */
export const userDeleted = onUserDeleted(async (event) => {
  const user = event.data; // UserRecord
  logger.info('User deleted', { uid: user.uid, email: user.email });

  // TODO: cleanup user data, revoke resources, etc.
});

// ───────────────────────────────────────────────────────────────────────────────
// Callable example (v2 onCall)
// ───────────────────────────────────────────────────────────────────────────────

/**
 * Example callable: createLead
 * v1: https.onCall((data, context) => {})
 * v2: onCall((request) => {})
 */
export const createLead = onCall(
  // Per-function options (replaces runWith on v1)
  { cors: true /* secrets: [ ... ] if needed */ },
  async (request: CallableRequest<any>) => {
    const { data, auth } = request;

    if (!auth) {
      throw new HttpsError('unauthenticated', 'You must be signed in.');
    }

    logger.info('createLead called', { uid: auth.uid, data });

    // TODO: implement your actual lead creation logic here
    // e.g., await saveLead(data, auth.uid);

    return { ok: true };
  }
);

// ───────────────────────────────────────────────────────────────────────────────
// HTTP endpoints (v2 onRequest)
// ───────────────────────────────────────────────────────────────────────────────

/**
 * Health check
 * v1: https.onRequest((req, res) => {})
 * v2: onRequest((req, res) => {})
 */
export const healthCheck = onRequest(
  { cors: true },
  async (req: Request, res: Response) => {
    if (req.method !== 'GET') {
      return res.status(405).set('Allow', 'GET').send('Method Not Allowed');
    }
    res.status(200).send('ok');
  }
);

/**
 * Stripe webhook (raw body access is available via req.rawBody in v2)
 * - Uses v2 options to declare secrets.
 */
export const stripeWebhook = onRequest(
  { cors: false, secrets: [STRIPE_SECRET, STRIPE_WEBHOOK_SECRET, STRIPE_API_VERSION] },
  async (req: Request, res: Response) => {
    // Verify method early
    if (req.method !== 'POST') {
      return res.status(405).set('Allow', 'POST').send('Method Not Allowed');
    }

    try {
      // In v2, raw body is always available on req.rawBody (Buffer)
      const sig = req.header('stripe-signature');
      if (!sig) {
        return res.status(400).send('Missing Stripe signature header');
      }

      // Dynamically import stripe to keep cold starts small if you like
      const { default: Stripe } = await import('stripe');

      const stripe = new Stripe(STRIPE_SECRET.value(), {
        apiVersion: (STRIPE_API_VERSION.value() || undefined) as any,
      });

      const endpointSecret = STRIPE_WEBHOOK_SECRET.value();

      const event = stripe.webhooks.constructEvent(
        req.rawBody,
        sig,
        endpointSecret
      );

      logger.info('Stripe event received', { type: event.type, id: event.id });

      // TODO: handle event types
      // switch (event.type) { ... }

      res.status(200).json({ received: true });
    } catch (err: any) {
      logger.error('Stripe webhook error', { message: err?.message, stack: err?.stack });
      res.status(400).send(`Webhook Error: ${err?.message ?? 'unknown'}`);
    }
  }
);

// ───────────────────────────────────────────────────────────────────────────────
// (Optional) Replace any v1 `runWith({...}).https.onRequest` or `.onCall`
// by passing the same options object as the first parameter above.
// ───────────────────────────────────────────────────────────────────────────────
