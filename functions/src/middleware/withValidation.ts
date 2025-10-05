import { onCall, CallableOptions } from 'firebase-functions/v2/https';

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
  schema: TSchema,
  options: CallableOptions
) {
  return (handler: (data: any, context: any) => Promise<TOut>) =>
    onCall(options, async (data, context) => {
      // ...existing code...
      return handler(data, context);
    });
}
