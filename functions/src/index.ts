import { onRequest } from 'firebase-functions/v2/https';
import { setGlobalOptions } from 'firebase-functions/v2';
// v2 identity triggers not yet supported in firebase-functions@5.x
// Remove until v2 API is available
import type { Request, Response } from 'express';

// Set default region close to Providence, RI
setGlobalOptions({ region: 'us-east4' });

// Re‑export callable/HTTP functions implemented in feature modules
export { createLead } from './leads/createLead';

// --- Health Check (HTTP) ----------------------------------------------------
export const healthCheck = onRequest((req: Request, res: Response) => {
  const payload = {
    status: 'ok',
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version || process.env.PACKAGE_VERSION || 'dev',
  } as const;
  res.status(200).json(payload);
});

// --- Auth triggers (v2) -----------------------------------------------------
// Interfaces removed (unused). If needed later, reintroduce with proper usage.
