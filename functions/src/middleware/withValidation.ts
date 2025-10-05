import { onCall, CallableOptions, CallableRequest } from 'firebase-functions/v2/https';

// Endpoint presets
export function publicEndpoint(opts: Partial<CallableOptions> = {}): CallableOptions {
  return { region: 'us-central1', ...opts };
}

export function authenticatedEndpoint(opts: Partial<CallableOptions> = {}): CallableOptions {
  return { region: 'us-central1', enforceAppCheck: true, ...opts };
}

export function adminEndpoint(opts: Partial<CallableOptions> = {}): CallableOptions {
  return { region: 'us-central1', enforceAppCheck: true, ...opts };
}

// Generic validation wrapper for v2 onCall
export function withValidation<TSchema, TOut = unknown>(
  _schema: TSchema,
  options: CallableOptions
) {
  return (handler: (validated: any, req: CallableRequest<any>) => Promise<TOut>) =>
    onCall(options, async (req: CallableRequest<any>) => {
      // Example schema usage (plug your validator here):
      const validated = req.data; // TODO: validate using _schema
      // Optionally enforce auth/admin here:
      // if (options.enforceAppCheck && !req.appCheckToken) throw new HttpsError('unauthenticated', 'App Check required');
      return handler(validated, req);
    });
}
