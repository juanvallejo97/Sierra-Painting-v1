/**
 * Audit Logging Utilities for Sierra Painting
 * 
 * PURPOSE:
 * Provide helpers for writing immutable audit log entries for sensitive operations.
 * Ensures compliance, traceability, and forensic analysis capability.
 * 
 * RESPONSIBILITIES:
 * - Write structured audit log entries to Firestore
 * - Capture actor, action, entity, timestamp, and context
 * - Support batch writes for atomic operations
 * - Extract request metadata (IP, user agent)
 * 
 * PUBLIC API:
 * - logAudit(entry: AuditLogEntry): Promise<void>
 * - createAuditEntry(params): AuditLogEntry
 * - extractRequestMetadata(request): { ipAddress, userAgent }
 * 
 * SECURITY CONSIDERATIONS:
 * - Audit logs are write-only (clients cannot read or modify)
 * - Logs are written to a separate collection for immutability
 * - PII (email, phone) should NOT be logged; use userId instead
 * - IP addresses are logged for forensic purposes (GDPR considerations)
 * 
 * PERFORMANCE NOTES:
 * - Audit writes are async (do not block main operation)
 * - Use batch writes for multiple audit entries
 * - Consider Cloud Pub/Sub for high-volume logging
 * 
 * INVARIANTS:
 * - Every payment operation MUST create an audit log
 * - Audit logs are append-only (no updates or deletes)
 * - Timestamp is server-side (FieldValue.serverTimestamp())
 * 
 * USAGE EXAMPLE:
 * ```typescript
 * await logAudit(createAuditEntry({
 *   entity: 'invoice',
 *   entityId: invoiceId,
 *   action: 'paid',
 *   actor: context.auth.uid,
 *   orgId: invoice.orgId,
 *   metadata: { amount: 15000, method: 'check' },
 * }));
 * ```
 * 
 * TODO:
 * - Add log rotation/archival for compliance (e.g., 7-year retention)
 * - Implement log aggregation for analytics (BigQuery export)
 * - Add encryption for sensitive metadata
 * - Consider write batching for performance
 */

import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import {AuditLogEntry, AuditLogEntrySchema} from './zodSchemas';

// ============================================================
// TYPES
// ============================================================

/**
 * Parameters for creating an audit entry
 */
export interface CreateAuditEntryParams {
  entity: 'invoice' | 'payment' | 'estimate' | 'user' | 'job' | 'timeEntry';
  entityId: string;
  action: 'created' | 'updated' | 'deleted' | 'paid' | 'sent' | 'approved';
  actor: string; // Firebase UID
  actorRole?: 'admin' | 'crew_lead' | 'crew' | 'customer';
  orgId: string;
  ipAddress?: string;
  userAgent?: string;
  changes?: Record<string, unknown>; // Old/new values for updates
  metadata?: Record<string, unknown>; // Additional context
}

/**
 * Request metadata extracted from Cloud Function context
 */
export interface RequestMetadata {
  ipAddress?: string;
  userAgent?: string;
}

// ============================================================
// CONSTANTS
// ============================================================

/**
 * Firestore collection for audit logs
 */
const AUDIT_COLLECTION = 'activityLog';

// ============================================================
// PUBLIC API
// ============================================================

/**
 * Create an audit log entry with current timestamp
 * 
 * @param params - Audit entry parameters
 * @returns Validated audit log entry
 * 
 * @example
 * const entry = createAuditEntry({
 *   entity: 'invoice',
 *   entityId: 'inv_123',
 *   action: 'paid',
 *   actor: 'user_abc',
 *   orgId: 'org_xyz',
 * });
 */
export function createAuditEntry(params: CreateAuditEntryParams): AuditLogEntry {
  const entry: AuditLogEntry = {
    entity: params.entity,
    entityId: params.entityId,
    action: params.action,
    actor: params.actor,
    actorRole: params.actorRole,
    orgId: params.orgId,
    timestamp: new Date().toISOString(),
    ipAddress: params.ipAddress,
    userAgent: params.userAgent,
    changes: params.changes,
    metadata: params.metadata,
  };

  // Validate with Zod schema
  return AuditLogEntrySchema.parse(entry);
}

/**
 * Write an audit log entry to Firestore
 * 
 * IMPORTANT: This is an async write that does not block the caller.
 * If the write fails, it will log an error but NOT throw.
 * 
 * @param entry - Validated audit log entry
 * @returns Promise<void>
 * 
 * @example
 * await logAudit(createAuditEntry({
 *   entity: 'payment',
 *   entityId: paymentId,
 *   action: 'created',
 *   actor: userId,
 *   orgId: orgId,
 *   metadata: { amount: 15000, method: 'check' },
 * }));
 */
export async function logAudit(entry: AuditLogEntry): Promise<void> {
  try {
    const db = admin.firestore();
    const docRef = db.collection(AUDIT_COLLECTION).doc();

    await docRef.set({
      ...entry,
      // Use server timestamp for consistency
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    functions.logger.info('Audit log written', {
      entity: entry.entity,
      entityId: entry.entityId,
      action: entry.action,
      actor: entry.actor,
      orgId: entry.orgId,
    });
  } catch (error) {
    // Log error but do NOT throw (audit failure should not block operations)
    functions.logger.error('Failed to write audit log', {
      entry,
      error,
    });
  }
}

/**
 * Write multiple audit log entries in a batch
 * 
 * Use this for atomic operations that affect multiple entities.
 * 
 * @param entries - Array of validated audit log entries
 * @returns Promise<void>
 * 
 * @example
 * await logAuditBatch([
 *   createAuditEntry({ entity: 'invoice', action: 'paid', ... }),
 *   createAuditEntry({ entity: 'payment', action: 'created', ... }),
 * ]);
 */
export async function logAuditBatch(entries: AuditLogEntry[]): Promise<void> {
  if (entries.length === 0) return;

  try {
    const db = admin.firestore();
    const batch = db.batch();

    for (const entry of entries) {
      const docRef = db.collection(AUDIT_COLLECTION).doc();
      batch.set(docRef, {
        ...entry,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    functions.logger.info('Audit log batch written', {
      count: entries.length,
      entities: entries.map((e) => e.entity),
    });
  } catch (error) {
    functions.logger.error('Failed to write audit log batch', {
      entries,
      error,
    });
  }
}

/**
 * Extract request metadata from Cloud Function context
 * 
 * @param request - HTTP request object (for HTTP functions)
 * @returns Request metadata (IP, user agent)
 * 
 * @example
 * const metadata = extractRequestMetadata(req);
 * const entry = createAuditEntry({
 *   ...params,
 *   ...metadata,
 * });
 */
export function extractRequestMetadata(
  request?: functions.https.Request
): RequestMetadata {
  if (!request) {
    return {};
  }

  return {
    ipAddress: request.ip || request.headers['x-forwarded-for'] as string,
    userAgent: request.headers['user-agent'] as string,
  };
}

/**
 * Extract context metadata from callable function context
 * 
 * @param context - CallableContext from callable functions
 * @returns Request metadata (IP, user agent)
 * 
 * @example
 * const metadata = extractCallableMetadata(context);
 * const entry = createAuditEntry({
 *   ...params,
 *   ...metadata,
 * });
 */
export function extractCallableMetadata(
  context: functions.https.CallableContext
): RequestMetadata {
  return {
    ipAddress: context.rawRequest?.ip,
    userAgent: context.rawRequest?.headers['user-agent'] as string,
  };
}

// ============================================================
// EXPORTS
// ============================================================

export default {
  createAuditEntry,
  logAudit,
  logAuditBatch,
  extractRequestMetadata,
  extractCallableMetadata,
};
