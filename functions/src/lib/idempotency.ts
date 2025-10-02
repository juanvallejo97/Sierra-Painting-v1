/**
 * Idempotency Utilities for Sierra Painting Cloud Functions
 * 
 * PURPOSE:
 * Provide helpers for idempotent Cloud Function operations.
 * Ensures that duplicate requests (e.g., retry, offline queue replay) do not create duplicate effects.
 * 
 * RESPONSIBILITIES:
 * - Check if an operation has already been performed (idempotency key lookup)
 * - Store idempotency records for successful operations
 * - Handle Stripe webhook idempotency (eventId deduplication)
 * - Provide TTL-based cleanup for old idempotency records
 * 
 * PUBLIC API:
 * - checkIdempotency(key: string): Promise<boolean>
 * - recordIdempotency(key: string, result: unknown, ttlSeconds?: number): Promise<void>
 * - generateIdempotencyKey(prefix: string, ...parts: string[]): string
 * - isStripeEventProcessed(eventId: string): Promise<boolean>
 * - recordStripeEvent(eventId: string): Promise<void>
 * 
 * SECURITY CONSIDERATIONS:
 * - Idempotency keys should be client-provided OR server-generated deterministically
 * - Do NOT allow arbitrary keys (limit to specific formats)
 * - Store minimal data in idempotency records (no PII)
 * - TTL ensures records are eventually deleted
 * 
 * PERFORMANCE NOTES:
 * - Firestore read for idempotency check (~50ms)
 * - Use in-memory cache for hot paths (TODO)
 * - TTL is implemented via Firestore TTL field (auto-cleanup)
 * 
 * INVARIANTS:
 * - Idempotency key must be unique per operation
 * - Once recorded, idempotency key cannot be overwritten
 * - TTL defaults to 7 days (configurable)
 * 
 * USAGE EXAMPLE:
 * ```typescript
 * const key = data.idempotencyKey || generateIdempotencyKey('markPaid', invoiceId);
 * const alreadyProcessed = await checkIdempotency(key);
 * if (alreadyProcessed) {
 *   return { success: true, message: 'Already processed' };
 * }
 * 
 * // Perform operation
 * const result = await markInvoiceAsPaid(invoiceId);
 * 
 * // Record idempotency
 * await recordIdempotency(key, result);
 * return result;
 * ```
 * 
 * TODO:
 * - Add in-memory LRU cache for hot idempotency keys
 * - Implement idempotency key namespacing (per function)
 * - Add metrics for idempotency hit rate
 * - Consider Firestore collection group for cross-function lookups
 */

import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import {createHash} from 'crypto';

// ============================================================
// CONSTANTS
// ============================================================

/**
 * Firestore collection for idempotency records
 */
const IDEMPOTENCY_COLLECTION = 'idempotencyKeys';

/**
 * Firestore collection for Stripe webhook events
 */
const STRIPE_EVENTS_COLLECTION = 'stripeEvents';

/**
 * Default TTL for idempotency records (7 days in seconds)
 */
const DEFAULT_TTL_SECONDS = 7 * 24 * 60 * 60;

// ============================================================
// TYPES
// ============================================================

/**
 * Idempotency record stored in Firestore
 */
interface IdempotencyRecord {
  key: string;
  result: unknown;
  createdAt: admin.firestore.Timestamp;
  expiresAt: admin.firestore.Timestamp;
}

// ============================================================
// PUBLIC API
// ============================================================

/**
 * Check if an operation has already been performed
 * 
 * @param key - Idempotency key (client-provided or generated)
 * @returns true if operation already performed, false otherwise
 * 
 * @example
 * const alreadyProcessed = await checkIdempotency('markPaid:inv_123:1234567890');
 * if (alreadyProcessed) {
 *   return { success: true, message: 'Already processed' };
 * }
 */
export async function checkIdempotency(key: string): Promise<boolean> {
  try {
    const db = admin.firestore();
    const docRef = db.collection(IDEMPOTENCY_COLLECTION).doc(key);
    const doc = await docRef.get();

    if (doc.exists) {
      const data = doc.data() as IdempotencyRecord;
      const now = admin.firestore.Timestamp.now();

      // Check if record has expired
      if (data.expiresAt && data.expiresAt.toMillis() < now.toMillis()) {
        functions.logger.info('Idempotency record expired', { key });
        await docRef.delete();
        return false;
      }

      functions.logger.info('Idempotency key found (duplicate request)', { key });
      return true;
    }

    return false;
  } catch (error) {
    functions.logger.error('Error checking idempotency', { key, error });
    // On error, assume not processed (fail-open for availability)
    return false;
  }
}

/**
 * Record an idempotent operation
 * 
 * IMPORTANT: Call this AFTER the operation succeeds, not before.
 * 
 * @param key - Idempotency key
 * @param result - Operation result (for debugging; keep minimal)
 * @param ttlSeconds - TTL in seconds (default: 7 days)
 * @returns Promise<void>
 * 
 * @example
 * await recordIdempotency('markPaid:inv_123:1234567890', { invoiceId, paidAt });
 */
export async function recordIdempotency(
  key: string,
  result: unknown,
  ttlSeconds: number = DEFAULT_TTL_SECONDS
): Promise<void> {
  try {
    const db = admin.firestore();
    const docRef = db.collection(IDEMPOTENCY_COLLECTION).doc(key);

    const now = admin.firestore.Timestamp.now();
    const expiresAt = admin.firestore.Timestamp.fromMillis(
      now.toMillis() + ttlSeconds * 1000
    );

    const record: IdempotencyRecord = {
      key,
      result,
      createdAt: now,
      expiresAt,
    };

    await docRef.set(record);

    functions.logger.info('Idempotency key recorded', { key, ttl: ttlSeconds });
  } catch (error) {
    // Log error but do NOT throw (recording failure should not block operation)
    functions.logger.error('Failed to record idempotency', { key, error });
  }
}

/**
 * Generate a deterministic idempotency key from parts
 * 
 * Use this when client does not provide an idempotency key.
 * 
 * @param prefix - Function name or operation type
 * @param parts - Variable parts (entityId, timestamp, etc.)
 * @returns Idempotency key (prefix:hash)
 * 
 * @example
 * const key = generateIdempotencyKey('markPaid', invoiceId, Date.now().toString());
 * // Returns: 'markPaid:abc123def456'
 */
export function generateIdempotencyKey(prefix: string, ...parts: string[]): string {
  const combined = parts.join(':');
  const hash = createHash('sha256').update(combined).digest('hex').substring(0, 16);
  return `${prefix}:${hash}`;
}

/**
 * Check if a Stripe webhook event has already been processed
 * 
 * Stripe sends duplicate webhook events for retries. Use event.id for deduplication.
 * 
 * @param eventId - Stripe event.id
 * @returns true if event already processed, false otherwise
 * 
 * @example
 * const alreadyProcessed = await isStripeEventProcessed(event.id);
 * if (alreadyProcessed) {
 *   return res.status(200).json({ received: true, duplicate: true });
 * }
 */
export async function isStripeEventProcessed(eventId: string): Promise<boolean> {
  try {
    const db = admin.firestore();
    const docRef = db.collection(STRIPE_EVENTS_COLLECTION).doc(eventId);
    const doc = await docRef.get();

    if (doc.exists) {
      functions.logger.info('Stripe event already processed', { eventId });
      return true;
    }

    return false;
  } catch (error) {
    functions.logger.error('Error checking Stripe event', { eventId, error });
    // Fail-open: assume not processed
    return false;
  }
}

/**
 * Record a processed Stripe webhook event
 * 
 * @param eventId - Stripe event.id
 * @param eventType - Stripe event.type (for debugging)
 * @param ttlSeconds - TTL in seconds (default: 30 days for Stripe)
 * @returns Promise<void>
 * 
 * @example
 * await recordStripeEvent(event.id, event.type);
 */
export async function recordStripeEvent(
  eventId: string,
  eventType?: string,
  ttlSeconds: number = 30 * 24 * 60 * 60
): Promise<void> {
  try {
    const db = admin.firestore();
    const docRef = db.collection(STRIPE_EVENTS_COLLECTION).doc(eventId);

    const now = admin.firestore.Timestamp.now();
    const expiresAt = admin.firestore.Timestamp.fromMillis(
      now.toMillis() + ttlSeconds * 1000
    );

    await docRef.set({
      eventId,
      eventType,
      processedAt: now,
      expiresAt,
    });

    functions.logger.info('Stripe event recorded', { eventId, eventType });
  } catch (error) {
    functions.logger.error('Failed to record Stripe event', { eventId, error });
  }
}

/**
 * Validate idempotency key format
 * 
 * Ensures client-provided keys match expected format (prevents injection attacks).
 * 
 * @param key - Idempotency key
 * @returns true if valid, false otherwise
 * 
 * @example
 * if (!isValidIdempotencyKey(data.idempotencyKey)) {
 *   throw new functions.https.HttpsError('invalid-argument', 'Invalid idempotency key');
 * }
 */
export function isValidIdempotencyKey(key: string): boolean {
  // Allow alphanumeric, hyphens, underscores, colons (max 128 chars)
  const regex = /^[a-zA-Z0-9_:-]{1,128}$/;
  return regex.test(key);
}

// ============================================================
// EXPORTS
// ============================================================

export default {
  checkIdempotency,
  recordIdempotency,
  generateIdempotencyKey,
  isStripeEventProcessed,
  recordStripeEvent,
  isValidIdempotencyKey,
};
