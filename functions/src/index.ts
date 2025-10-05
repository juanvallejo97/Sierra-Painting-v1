/* eslint-disable import/no-extraneous-dependencies */
import { onRequest } from 'firebase-functions/v2/https';
import { onUserCreated, onUserDeleted } from 'firebase-functions/v2/auth';
import { logger } from 'firebase-functions';
import type { Request, Response } from 'express';

// Re‑export callable/HTTP functions implemented in feature modules
export { createLead } from './leads/createLead';

// --- Health Check (HTTP) ----------------------------------------------------
export const healthCheck = onRequest((req: Request, res: Response) => {
  // Simple readiness probe for Cloud Run / uptime checks
  res.status(200).send({ ok: true, ts: Date.now() });
});

// --- Auth triggers (v2) -----------------------------------------------------
interface UserCreatedEvent {
  data: {
    uid?: string;
    email?: string;
    [key: string]: any;
  };
}

export const handleUserCreated = onUserCreated((event: UserCreatedEvent) => {
  const user = event.data;
  logger.info('Auth user created', { uid: user?.uid, email: user?.email });
});

interface UserDeletedEvent {
  data: {
    uid?: string;
    email?: string;
    [key: string]: any;
  };
}

export const handleUserDeleted = onUserDeleted((event: UserDeletedEvent) => {
  const user = event.data;
  logger.info('Auth user deleted', { uid: user?.uid, email: user?.email });
});
