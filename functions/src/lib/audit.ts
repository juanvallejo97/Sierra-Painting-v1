import { logger } from 'firebase-functions';
import type { CallableRequest } from 'firebase-functions/v2/https';

export interface AuditEntry {
  entity: string;
  entityId: string;
  action: 'created' | 'updated' | 'deleted';
  actor: string;
  orgId?: string;
  ts?: number;
  metadata?: Record<string, unknown>;
}

/** Create a normalized audit entry */
export function createAuditEntry(entry: AuditEntry): AuditEntry {
  return { ts: Date.now(), ...entry };
}

/** Extract useful request metadata from v2 CallableRequest */
export function extractCallableMetadata(req: CallableRequest): Record<string, unknown> {
  return {
    appCheck: Boolean(req.app),
    authenticated: Boolean(req.auth?.uid),
    uid: req.auth?.uid ?? null,
  };
}

/** Persist/log audit entry.  Replace with Firestore/BigQuery if desired. */
export async function logAudit(entry: AuditEntry): Promise<void> {
  logger.info('audit', entry);
}
