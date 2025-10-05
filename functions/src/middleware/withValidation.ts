import { onCall, HttpsError, type CallableRequest, type HttpsOptions } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';
import type { ZodSchema } from 'zod';

/**
 * Wrap a v2 onCall with Zod validation + optional extra options.
 * App Check is enforced by default.
 */
export function withValidation<T>(
  schema: ZodSchema<T>,
  handler: (data: T, req: CallableRequest) => Promise<unknown>,
  options: HttpsOptions = {}
) {
  const merged: HttpsOptions = {
    enforceAppCheck: true,
    consumeAppCheckToken: true,
    ...options,
  };

  return onCall(merged, async (req) => {
    let parsed: T;

    try {
      parsed = schema.parse(req.data);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Invalid request';
      logger.warn('Validation failed', { message });
      throw new HttpsError('invalid-argument', message);
    }

    try {
      return await handler(parsed, req);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Unknown error';
      logger.error('Callable handler failed', { message });
      throw new HttpsError('internal', message);
    }
  });
}
