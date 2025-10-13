/**
 * App Check enforcement for Callable Functions
 *
 * Provides environment-gated App Check validation for onCall functions.
 * - In local dev (ENFORCE_APPCHECK=false): Skips validation
 * - In staging/prod (ENFORCE_APPCHECK=true): Requires valid App Check token
 *
 * Usage:
 * ```typescript
 * import { ensureAppCheck } from '../middleware/ensureAppCheck';
 *
 * export const myFunction = functions.onCall({}, async (req) => {
 *   ensureAppCheck(req); // Add this as first line
 *   // ... rest of function logic
 * });
 * ```
 */

import { HttpsError, type CallableRequest } from 'firebase-functions/v2/https';

/**
 * Validates App Check token for callable functions
 * Throws HttpsError if validation fails and enforcement is enabled
 *
 * @param req - Callable request object
 * @throws HttpsError('failed-precondition') if App Check is required but missing
 */
export function ensureAppCheck(req: CallableRequest): void {
  const enforce = (process.env.ENFORCE_APPCHECK || 'false').toLowerCase() === 'true';

  if (!enforce) {
    // Local development mode - skip validation
    return;
  }

  // Production mode - require App Check token
  if (!req.app) {
    throw new HttpsError('failed-precondition', 'App Check token required');
  }
}
