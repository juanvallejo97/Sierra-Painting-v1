/**
 * withValidation (v2)
 *
 * Small helper for v2 `onCall` functions that:
 *  - Enforces App Check
 *  - Optionally enforces Auth
 *  - Validates payload with Zod (typed)
 *
 * Usage:
 *   export const doThing = withValidation({
 *     schema: MyZodSchema,
 *     requireAuth: true
 *   }, async ({ data, auth, app }) => {
 *     // data is typed, auth/app are from CallableRequest
 *     return { ok: true };
 *   });
 */

import { onCall, HttpsError, type CallableRequest, type HttpsOptions } from 'firebase-functions/v2/https';
import type { z, ZodSchema } from 'zod';
import { warn } from 'firebase-functions/logger';

type WithValidationConfig<TIn> = {
  /** Zod schema for request payload */
  schema: ZodSchema<TIn>;
  /** Require Firebase Auth? (default: false) */
  requireAuth?: boolean;
  /** Optional per-function options; most defaults are set with setGlobalOptions */
  options?: HttpsOptions;
};

type WithValidationHandler<TIn, TOut> = (args: {
  data: TIn;
  /** Auth info from CallableRequest (may be undefined if not required) */
  auth: CallableRequest<TIn>['auth'];
  /** App Check info from CallableRequest */
  app: CallableRequest<TIn>['app'];
  /** Full raw request if you need headers, etc. */
  raw: CallableRequest<TIn>;
}) => Promise<TOut> | TOut;

export function withValidation<TIn, TOut>(
  cfg: WithValidationConfig<TIn>,
  handler: WithValidationHandler<TIn, TOut>
) {
  return onCall(cfg.options ?? {}, async (req: CallableRequest<unknown>) => {
    // 1) Enforce App Check (defense-in-depth)
    if (!req.app) {
      warn('App Check missing or invalid');
      throw new HttpsError('failed-precondition', 'App Check validation failed');
    }

    // 2) Optional Auth requirement
    if (cfg.requireAuth && !req.auth) {
      throw new HttpsError('unauthenticated', 'Authentication is required');
    }

    // 3) Zod parsing (strongly typed)
    let parsed: TIn;
    try {
      parsed = cfg.schema.parse(req.data) as TIn;
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'Invalid payload';
      throw new HttpsError('invalid-argument', msg);
    }

    // 4) Invoke user handler with typed data
    return handler({
      data: parsed,
      auth: req.auth as CallableRequest<TIn>['auth'],
      app: req.app as CallableRequest<TIn>['app'],
      raw: req as CallableRequest<TIn>,
    });
  });
}

// Optional tiny helpers if you want to keep the old call sites:
// parse only, or simple guards you can reuse elsewhere.
export function parseWith<TIn>(schema: ZodSchema<TIn>, data: unknown): TIn {
  return schema.parse(data);
}
export function assertAuth(req: CallableRequest<unknown>) {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Authentication is required');
}
export function assertAppCheck(req: CallableRequest<unknown>) {
  if (!req.app) throw new HttpsError('failed-precondition', 'App Check validation failed');
}
