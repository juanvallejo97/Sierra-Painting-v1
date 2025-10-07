// functions/src/middleware/withValidation.ts
import type { Request, Response, NextFunction } from 'express';
import type { ZodSchema, ZodError } from 'zod';
import admin from 'firebase-admin';

const MAX_PAYLOAD_BYTES = 10 * 1024 * 1024; // 10MB

export type ValidationSchemas<
  TBody = unknown,
  TQuery = unknown,
  TParams = unknown
> = {
  body?: ZodSchema<TBody>;
  query?: ZodSchema<TQuery>;
  params?: ZodSchema<TParams>;
};

export type AdminOptions = {
  requireAdmin?: boolean;
  functionName?: string;
  region?: string;
  // optional custom role check used by some callers/tests
  customRoleCheck?: (role: string) => boolean;
};

/**
 * Small helper used by callers to mark an endpoint as admin-only.
 * Example: withValidation(schema, adminEndpoint({ functionName: 'foo' }))(handler)
 */
export function adminEndpoint(opts: AdminOptions = {}): AdminOptions {
  return { requireAdmin: true, ...opts };
}

/**
 * Flexible validation wrapper that supports both Firebase Callable-style
 * handlers (data, context) and Express handlers (req, res, next).
 *
 * Usage (callable):
 *   export const fn = withValidation(schema, options)(async (data, context) => { ... })
 *
 * Usage (express):
 *   app.post('/x', withValidation({ body: schema })(async (req,res) => { ... }))
 */
export function withValidation(
  schemas: ZodSchema<unknown> | ValidationSchemas | undefined,
  options?: AdminOptions
) {
  // Return a wrapper that accepts a generic handler. We avoid strict typing here
  // to match many different usage sites in the repo (callable + express).
  // handler can be either an express handler or a callable-style function
  return function (handler: (...args: any[]) => any) {
    return async function (...args: any[]) {
      // Detect Express signature (req, res, next)
      if (args.length >= 2 && args[0] && args[0].headers !== undefined && args[1] && args[1].status) {
  // cast from unknown args to Express types
  const req = args[0] as any as Request;
  const res = args[1] as any as Response;
  const next = args[2] as any as NextFunction | undefined;

        try {
          // Basic payload size guard
          const contentLength = Number(req.headers['content-length'] ?? 0);
          const bodySize = contentLength || Buffer.byteLength(JSON.stringify(req.body ?? {}));
          if (bodySize > MAX_PAYLOAD_BYTES) {
            throw new Error('Payload size exceeds maximum allowed size');
          }

          // Apply validation if provided as ValidationSchemas
          if (schemas && typeof (schemas as ValidationSchemas).body !== 'undefined') {
            const s = schemas as ValidationSchemas;
            if (s.body) req.body = s.body.parse(req.body) as any;
            if (s.query) req.query = s.query.parse(req.query) as any;
            if (s.params) req.params = s.params.parse(req.params) as any;
          }

          await Promise.resolve(handler(req, res, next));
        } catch (err) {
          if (isZodError(err)) {
            res.status(400).json({ error: 'ValidationError', details: err.issues });
            return;
          }
          if (next) next(err as Error);
          else throw err;
        }
        return;
      }

    // Otherwise treat as callable-style: (data, context)
  let data: any = args[0];
  const context: any = args[1] ?? {};

      try {
        // Enforce payload size for callable
        const payloadBytes = Buffer.byteLength(JSON.stringify(data ?? {}));
        if (payloadBytes > MAX_PAYLOAD_BYTES) {
          throw new Error('Payload size exceeds maximum allowed size');
        }

        // If a simple ZodSchema was provided, validate the entire data payload
        if (schemas && typeof (schemas as ZodSchema).parse === 'function') {
          data = (schemas as ZodSchema).parse(data);
        } else if (schemas && (schemas as ValidationSchemas).body) {
          data = (schemas as ValidationSchemas).body!.parse(data);
        }

        // Admin checks if requested
        if (options?.requireAdmin) {
          const uid = context?.auth?.uid;
          if (!uid) throw new Error('Insufficient permissions');

          const db = admin.firestore();
          const userDoc = await db.collection('users').doc(uid).get();
          if (!userDoc.exists) throw new Error('User profile not found');
          const role = (userDoc.data() as any).role as string | undefined;
          const roleCheck = options.customRoleCheck ?? ((r: string) => r === 'admin');
          if (!roleCheck(role as string)) throw new Error('Insufficient permissions');
        }

        return await Promise.resolve(handler(data, context));
      } catch (err) {
        // Preserve thrown HttpsError-like objects; normalize non-Error to Error so tests can assert
        if (err && typeof err === 'object' && (err as any).name === 'HttpsError') {
          throw err;
        }
        if (!(err instanceof Error)) {
          throw new Error((err as any)?.message ?? String(err));
        }
        throw err;
      }
    };
  };
}

function isZodError(e: unknown): e is ZodError<unknown> {
  return Boolean(
    e &&
      typeof e === 'object' &&
      'issues' in (e as Record<string, unknown>) &&
      Array.isArray((e as { issues: unknown[] }).issues)
  );
}
