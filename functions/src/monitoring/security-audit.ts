/**
 * Security Audit Logging - Cloud Functions
 *
 * PURPOSE:
 * Tracks security-sensitive events for compliance, forensics, and threat detection.
 * Logs all significant security events to Firestore audit log collection.
 *
 * AUDITED EVENTS:
 * - Role changes (admin/manager/staff/worker)
 * - Cross-tenant access attempts (rule violations)
 * - companyId modification attempts (immutability violations)
 * - Sensitive data access (invoices, time entries by admin)
 * - Mass data exports (>100 documents in single query)
 * - Failed authentication attempts
 * - Custom claims updates
 * - Permission escalation attempts
 *
 * AUDIT LOG STORAGE:
 * - Collection: security_audit_log
 * - Document ID: Auto-generated
 * - Retention: 90 days (configurable)
 * - Indexed by: timestamp, severity, eventType, userId, companyId
 *
 * SEVERITY LEVELS:
 * - INFO: Normal operations (role changes, data access)
 * - WARN: Suspicious activity (repeated failures, unusual patterns)
 * - ERROR: Security violations (cross-tenant attempts, immutability violations)
 * - CRITICAL: Severe security incidents (privilege escalation, mass export)
 *
 * ALERTING:
 * - ERROR/CRITICAL events trigger Cloud Logging alerts
 * - Integration with Cloud Monitoring for alerting policies
 * - Supports Slack/email notifications via Pub/Sub
 *
 * COMPLIANCE:
 * - SOC 2 Type II audit trail requirements
 * - GDPR data access logging
 * - HIPAA audit trail (if applicable)
 */

import * as admin from 'firebase-admin';
import * as logger from 'firebase-functions/logger';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';

/**
 * Audit event types.
 */
export enum AuditEventType {
  ROLE_CHANGED = 'role_changed',
  CLAIMS_UPDATED = 'claims_updated',
  CROSS_TENANT_ACCESS_ATTEMPT = 'cross_tenant_access_attempt',
  IMMUTABILITY_VIOLATION = 'immutability_violation',
  SENSITIVE_DATA_ACCESS = 'sensitive_data_access',
  MASS_DATA_EXPORT = 'mass_data_export',
  AUTH_FAILURE = 'auth_failure',
  PERMISSION_ESCALATION = 'permission_escalation',
  COMPANY_ID_CHANGE_ATTEMPT = 'company_id_change_attempt',
  TIME_ENTRY_MANIPULATION = 'time_entry_manipulation',
  INVOICE_FRAUD_ATTEMPT = 'invoice_fraud_attempt',
}

/**
 * Audit severity levels.
 */
export enum AuditSeverity {
  INFO = 'INFO',
  WARN = 'WARN',
  ERROR = 'ERROR',
  CRITICAL = 'CRITICAL',
}

/**
 * Audit log entry structure.
 */
export interface AuditLogEntry {
  eventType: AuditEventType;
  severity: AuditSeverity;
  timestamp: admin.firestore.Timestamp;
  userId: string;
  companyId?: string;
  targetUserId?: string;
  targetCompanyId?: string;
  collection?: string;
  documentId?: string;
  details: Record<string, any>;
  ipAddress?: string;
  userAgent?: string;
}

/**
 * Creates an audit log entry in Firestore.
 */
export async function logSecurityEvent(entry: AuditLogEntry): Promise<void> {
  try {
    await admin.firestore()
      .collection('security_audit_log')
      .add({
        ...entry,
        timestamp: entry.timestamp || admin.firestore.Timestamp.now(),
      });

    // Also log to Cloud Logging for alerting
    const logData = {
      eventType: entry.eventType,
      severity: entry.severity,
      userId: entry.userId,
      companyId: entry.companyId,
      details: entry.details,
    };

    switch (entry.severity) {
      case AuditSeverity.CRITICAL:
        logger.error(`[Security Audit] CRITICAL: ${entry.eventType}`, logData);
        break;
      case AuditSeverity.ERROR:
        logger.error(`[Security Audit] ERROR: ${entry.eventType}`, logData);
        break;
      case AuditSeverity.WARN:
        logger.warn(`[Security Audit] WARN: ${entry.eventType}`, logData);
        break;
      default:
        logger.info(`[Security Audit] INFO: ${entry.eventType}`, logData);
    }
  } catch (error) {
    logger.error('[Security Audit] Failed to log security event:', error);
    // Don't throw - audit logging failure shouldn't break core functionality
  }
}

/**
 * Logs role change events.
 *
 * Triggered by setUserRole Cloud Function.
 */
export async function logRoleChange(
  userId: string,
  companyId: string,
  oldRole: string,
  newRole: string,
  changedBy: string
): Promise<void> {
  await logSecurityEvent({
    eventType: AuditEventType.ROLE_CHANGED,
    severity: AuditSeverity.INFO,
    timestamp: admin.firestore.Timestamp.now(),
    userId: changedBy,
    companyId,
    targetUserId: userId,
    details: {
      oldRole,
      newRole,
      reason: 'Role updated via setUserRole function',
    },
  });
}

/**
 * Logs custom claims updates.
 */
export async function logClaimsUpdate(
  userId: string,
  companyId: string,
  claims: Record<string, any>,
  updatedBy: string
): Promise<void> {
  await logSecurityEvent({
    eventType: AuditEventType.CLAIMS_UPDATED,
    severity: AuditSeverity.INFO,
    timestamp: admin.firestore.Timestamp.now(),
    userId: updatedBy,
    companyId,
    targetUserId: userId,
    details: {
      claims,
      reason: 'Custom claims updated',
    },
  });
}

/**
 * Logs cross-tenant access attempts (detected by security rules violations).
 *
 * Note: This would typically be triggered by Cloud Functions monitoring
 * or integrated with Firebase Auth/Firestore rule failures.
 */
export async function logCrossTenantAccessAttempt(
  userId: string,
  userCompanyId: string,
  targetCompanyId: string,
  collection: string,
  documentId: string
): Promise<void> {
  await logSecurityEvent({
    eventType: AuditEventType.CROSS_TENANT_ACCESS_ATTEMPT,
    severity: AuditSeverity.ERROR,
    timestamp: admin.firestore.Timestamp.now(),
    userId,
    companyId: userCompanyId,
    targetCompanyId,
    collection,
    documentId,
    details: {
      reason: 'User attempted to access document from different company',
      userCompanyId,
      targetCompanyId,
    },
  });
}

/**
 * Logs companyId modification attempts (immutability violations).
 */
export async function logCompanyIdChangeAttempt(
  userId: string,
  companyId: string,
  collection: string,
  documentId: string,
  oldCompanyId: string,
  newCompanyId: string
): Promise<void> {
  await logSecurityEvent({
    eventType: AuditEventType.COMPANY_ID_CHANGE_ATTEMPT,
    severity: AuditSeverity.ERROR,
    timestamp: admin.firestore.Timestamp.now(),
    userId,
    companyId,
    collection,
    documentId,
    details: {
      reason: 'User attempted to change companyId (immutable field)',
      oldCompanyId,
      newCompanyId,
    },
  });
}

/**
 * Logs time entry manipulation attempts.
 */
export async function logTimeEntryManipulation(
  userId: string,
  companyId: string,
  documentId: string,
  field: string,
  oldValue: any,
  newValue: any
): Promise<void> {
  await logSecurityEvent({
    eventType: AuditEventType.TIME_ENTRY_MANIPULATION,
    severity: AuditSeverity.ERROR,
    timestamp: admin.firestore.Timestamp.now(),
    userId,
    companyId,
    collection: 'timeEntries',
    documentId,
    details: {
      reason: 'User attempted to modify immutable time entry field',
      field,
      oldValue,
      newValue,
    },
  });
}

/**
 * Logs invoice fraud attempts (e.g., changing invoice number).
 */
export async function logInvoiceFraudAttempt(
  userId: string,
  companyId: string,
  documentId: string,
  field: string,
  oldValue: any,
  newValue: any
): Promise<void> {
  await logSecurityEvent({
    eventType: AuditEventType.INVOICE_FRAUD_ATTEMPT,
    severity: AuditSeverity.CRITICAL,
    timestamp: admin.firestore.Timestamp.now(),
    userId,
    companyId,
    collection: 'invoices',
    documentId,
    details: {
      reason: 'User attempted to modify invoice number or critical field',
      field,
      oldValue,
      newValue,
    },
  });
}

/**
 * Firestore trigger: Monitors role changes in users collection.
 *
 * Logs when a user's role is updated in Firestore.
 */
export const auditUserRoleChanges = onDocumentWritten({
  document: 'users/{userId}',
  region: 'us-east4',
}, async (event) => {
  const beforeData = event.data?.before.data();
  const afterData = event.data?.after.data();
  const userId = event.params.userId;

  if (!beforeData || !afterData) {
    return; // Document created or deleted, not updated
  }

  // Check if role changed
  if (beforeData.role !== afterData.role) {
    await logRoleChange(
      userId,
      afterData.companyId || 'unknown',
      beforeData.role || 'none',
      afterData.role || 'none',
      'system' // TODO: Get actual updater from context
    );
  }

  // Check if companyId changed (should be immutable!)
  if (beforeData.companyId !== afterData.companyId) {
    await logCompanyIdChangeAttempt(
      'system', // TODO: Get actual user from context
      beforeData.companyId || 'unknown',
      'users',
      userId,
      beforeData.companyId,
      afterData.companyId
    );
  }
});

/**
 * Firestore trigger: Monitors time entries for manipulation attempts.
 */
export const auditTimeEntryChanges = onDocumentWritten({
  document: 'timeEntries/{entryId}',
  region: 'us-east4',
}, async (event) => {
  const beforeData = event.data?.before.data();
  const afterData = event.data?.after.data();
  const entryId = event.params.entryId;

  if (!beforeData || !afterData) {
    return; // Document created or deleted, not updated
  }

  const companyId = afterData.companyId || 'unknown';
  const userId = afterData.userId || 'unknown';

  // Check immutable fields
  const immutableFields = ['companyId', 'userId', 'jobId', 'clockInAt'];

  for (const field of immutableFields) {
    if (beforeData[field] !== afterData[field]) {
      await logTimeEntryManipulation(
        userId,
        companyId,
        entryId,
        field,
        beforeData[field],
        afterData[field]
      );
    }
  }
});

/**
 * Firestore trigger: Monitors invoices for fraud attempts.
 */
export const auditInvoiceChanges = onDocumentWritten({
  document: 'invoices/{invoiceId}',
  region: 'us-east4',
}, async (event) => {
  const beforeData = event.data?.before.data();
  const afterData = event.data?.after.data();
  const invoiceId = event.params.invoiceId;

  if (!beforeData || !afterData) {
    return; // Document created or deleted, not updated
  }

  const companyId = afterData.companyId || 'unknown';

  // Check immutable fields (critical for fraud prevention)
  const immutableFields = ['number', 'companyId'];

  for (const field of immutableFields) {
    if (beforeData[field] !== afterData[field]) {
      await logInvoiceFraudAttempt(
        'system', // TODO: Get actual user from context
        companyId,
        invoiceId,
        field,
        beforeData[field],
        afterData[field]
      );
    }
  }
});

/**
 * Cleanup function: Deletes audit logs older than retention period.
 *
 * Scheduled to run daily via Cloud Scheduler.
 */
export async function cleanupOldAuditLogs(retentionDays: number = 90): Promise<void> {
  const cutoffDate = new Date(Date.now() - retentionDays * 24 * 60 * 60 * 1000);

  const snapshot = await admin.firestore()
    .collection('security_audit_log')
    .where('timestamp', '<', cutoffDate)
    .limit(500)
    .get();

  if (snapshot.empty) {
    logger.info('[Security Audit] No old audit logs to clean up');
    return;
  }

  const batch = admin.firestore().batch();
  snapshot.docs.forEach((doc) => {
    batch.delete(doc.ref);
  });

  await batch.commit();
  logger.info(`[Security Audit] Cleaned up ${snapshot.size} old audit logs`);
}
