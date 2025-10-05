/**
 * Cloud Functions entry (v2)
 *
 * - Initializes Admin SDK (singleton)
 * - Sets global defaults (region/memory/timeout)
 * - Re‑exports feature modules (createLead, webhooks, etc.)
 * - Provides small shared exports (db) so other modules can `import { db } from '..'`
 * - Adds a simple /healthCheck HTTP endpoint
 */

import * as admin from 'firebase-admin';
import { getFirestore } from 'firebase-admin/firestore';
import { setGlobalOptions } from 'firebase-functions/v2/options';
import { onRequest } from 'firebase-functions/v2/https';
import { onUserCreated, onUserDeleted } from 'firebase-functions/v2/auth';
import { info, warn, error } from 'firebase-functions/logger';
import type { Request, Response } from 'express';

// -----------------------------------------------------------------------------
// Admin initialization (idempotent)
// -----------------------------------------------------------------------------
if (admin.apps.length === 0) {
  admin.initializeApp();
}

// Make Firestore available to modules that import from ".."
export const db = getFirestore();

// -----------------------------------------------------------------------------
// Global defaults (tweak as you like)
// -----------------------------------------------------------------------------
setGlobalOptions({
  region: process.env.FUNCTIONS_REGION ?? 'us-central1',
  memory: '256MiB',
  timeoutSeconds: 60,
});

// -----------------------------------------------------------------------------
// Re-exports of feature modules
// (Keep these as thin exports to avoid circular deps.)
// -----------------------------------------------------------------------------

// Callable lead creation (kept as-is in its module)
export { createLead } from './leads/createLead';

// Stripe webhook (expects to be v2 onRequest in its own file)
export { stripeWebhook } from './payments/stripeWebhook';

// -----------------------------------------------------------------------------
// Simple health check (useful for uptime probes / smoke tests)
// -----------------------------------------------------------------------------
export const healthCheck = onRequest((req: Request, res: Response) => {
  res.status(200).json({
    ok: true,
    ts: Date.now(),
    region: process.env.FUNCTIONS_REGION ?? 'us-central1',
  });
});

// -----------------------------------------------------------------------------
// Minimal auth lifecycle hooks (optional – adjust or remove)
// -----------------------------------------------------------------------------
export const onAuthUserCreated = onUserCreated((event) => {
  info('Auth user created', { uid: event.data.uid, ts: Date.now() });
});

export const onAuthUserDeleted = onUserDeleted((event) => {
  warn('Auth user deleted', { uid: event.data.uid, ts: Date.now() });
});
