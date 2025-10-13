/**
 * Rate Limiter Middleware for Cloud Functions
 *
 * Implements Firestore-based rate limiting with sliding window algorithm.
 * Prevents abuse of public endpoints like createLead.
 *
 * STRATEGY:
 * - Track request counts per identifier (IP, email, phone)
 * - Sliding window: last N minutes
 * - Automatic cleanup of old entries via Firestore TTL (requires TTL policy)
 *
 * USAGE:
 * ```typescript
 * import { checkRateLimit } from './middleware/rateLimiter';
 *
 * const ip = req.headers['x-forwarded-for'] || req.ip;
 * await checkRateLimit('createLead', ip, 10, 3600); // 10 requests per hour
 * ```
 */

import * as admin from 'firebase-admin';
import { HttpsError } from 'firebase-functions/v2/https';

/**
 * Check rate limit for a given identifier
 *
 * @param operation - Operation name (e.g., 'createLead')
 * @param identifier - Unique identifier (IP, email, phone)
 * @param maxRequests - Maximum requests allowed in window
 * @param windowSeconds - Time window in seconds
 * @throws HttpsError if rate limit exceeded
 */
export async function checkRateLimit(
  operation: string,
  identifier: string,
  maxRequests: number,
  windowSeconds: number
): Promise<void> {
  const db = admin.firestore();
  const now = Date.now();
  const windowStart = now - windowSeconds * 1000;

  // Hash identifier for privacy (don't store raw IPs/emails)
  const hashedId = hashIdentifier(identifier);
  const docId = `${operation}_${hashedId}`;

  const rateLimitRef = db.collection('rateLimits').doc(docId);

  try {
    await db.runTransaction(async (tx) => {
      const doc = await tx.get(rateLimitRef);

      if (!doc.exists) {
        // First request - create entry
        tx.set(rateLimitRef, {
          operation,
          count: 1,
          windowStart: new Date(now),
          lastRequest: new Date(now),
          expiresAt: new Date(now + windowSeconds * 1000),
        });
        return;
      }

      const data = doc.data()!;
      const currentWindowStart = data.windowStart.toMillis();

      // Check if current window has expired
      if (currentWindowStart < windowStart) {
        // Window expired - reset counter
        tx.set(rateLimitRef, {
          operation,
          count: 1,
          windowStart: new Date(now),
          lastRequest: new Date(now),
          expiresAt: new Date(now + windowSeconds * 1000),
        });
        return;
      }

      // Window still active - check count
      if (data.count >= maxRequests) {
        const resetTime = new Date(currentWindowStart + windowSeconds * 1000);
        const retryAfterSeconds = Math.ceil((resetTime.getTime() - now) / 1000);

        throw new HttpsError(
          'resource-exhausted',
          `Rate limit exceeded. Try again in ${retryAfterSeconds} seconds.`
        );
      }

      // Increment counter
      tx.update(rateLimitRef, {
        count: admin.firestore.FieldValue.increment(1),
        lastRequest: new Date(now),
      });
    });
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    // Log unexpected errors but don't block request (fail open)
    console.error('Rate limit check failed:', error);
  }
}

/**
 * Hash identifier for privacy
 * Uses SHA-256 to hash IP/email/phone before storing
 */
function hashIdentifier(identifier: string): string {
  const crypto = require('crypto');
  return crypto
    .createHash('sha256')
    .update(identifier.toLowerCase().trim())
    .digest('hex')
    .substring(0, 32); // Use first 32 chars for shorter doc IDs
}

/**
 * Get client IP from request
 * Handles X-Forwarded-For header from load balancers
 */
export function getClientIP(req: any): string {
  // Try X-Forwarded-For first (set by Firebase Hosting, Cloud Load Balancer)
  const forwarded = req.headers['x-forwarded-for'];
  if (forwarded) {
    // May be comma-separated list, take first IP
    return forwarded.split(',')[0].trim();
  }

  // Fallback to direct IP
  return req.ip || req.connection?.remoteAddress || 'unknown';
}

/**
 * Create rate limit entry in Firestore (for testing/debugging)
 * This can be used to manually reset rate limits if needed
 */
export async function resetRateLimit(
  operation: string,
  identifier: string
): Promise<void> {
  const db = admin.firestore();
  const hashedId = hashIdentifier(identifier);
  const docId = `${operation}_${hashedId}`;

  await db.collection('rateLimits').doc(docId).delete();
}
