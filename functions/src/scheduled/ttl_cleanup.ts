/**
 * TTL Cleanup Cloud Functions
 *
 * PURPOSE:
 * Scheduled functions that automatically delete expired data based on retention policy.
 * Implements data lifecycle management and GDPR compliance.
 *
 * RETENTION POLICY (from PR-QA06):
 * - estimates: 3 years from createdAt (if not accepted)
 * - assignments: 2 years from endDate (if not active)
 * - _audit logs: 1 year from timestamp
 * - _probes: 30 days from createdAt
 * - _backups metadata: 30 days from createdAt
 *
 * SCHEDULE: Daily at 2:00 AM UTC (low traffic time)
 * REGION: us-east4
 *
 * SAFETY:
 * - Dry-run mode available for testing
 * - Batch deletions (limit 500 per run)
 * - Audit logging for all deletions
 * - Cannot delete time entries or invoices (7-year retention)
 */

import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onCall, CallableRequest, HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Deletion result
 */
interface DeletionResult {
  collection: string;
  deletedCount: number;
  dryRun: boolean;
  cutoffDate: Date;
  duration: number;
}

/**
 * Clean up expired estimates (3 years retention)
 *
 * Deletes estimates that:
 * - Are older than 3 years (from createdAt)
 * - Were NOT accepted (accepted estimates become jobs, kept for 5 years)
 * - Status is 'draft', 'sent', 'rejected', or 'expired'
 */
async function cleanupExpiredEstimates(dryRun: boolean = false): Promise<DeletionResult> {
  const db = admin.firestore();
  const startTime = Date.now();

  // Calculate cutoff date (3 years ago)
  const cutoffDate = new Date();
  cutoffDate.setFullYear(cutoffDate.getFullYear() - 3);

  logger.info(`Cleaning up estimates older than ${cutoffDate.toISOString()}`);

  // Query estimates
  const query = db
    .collection('estimates')
    .where('createdAt', '<', admin.firestore.Timestamp.fromDate(cutoffDate))
    .where('status', 'in', ['draft', 'sent', 'rejected', 'expired'])
    .limit(500); // Safety limit

  const snapshot = await query.get();

  if (snapshot.empty) {
    logger.info('No expired estimates to delete');
    return {
      collection: 'estimates',
      deletedCount: 0,
      dryRun,
      cutoffDate,
      duration: Date.now() - startTime,
    };
  }

  // Delete in batch
  if (!dryRun) {
    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });
    await batch.commit();
  }

  const deletedCount = snapshot.size;

  logger.info(`Deleted ${deletedCount} expired estimates`, {
    collection: 'estimates',
    deletedCount,
    dryRun,
    cutoffDate: cutoffDate.toISOString(),
  });

  return {
    collection: 'estimates',
    deletedCount,
    dryRun,
    cutoffDate,
    duration: Date.now() - startTime,
  };
}

/**
 * Clean up expired assignments (2 years retention)
 *
 * Deletes assignments that:
 * - endDate is more than 2 years ago
 * - active is false
 */
async function cleanupExpiredAssignments(dryRun: boolean = false): Promise<DeletionResult> {
  const db = admin.firestore();
  const startTime = Date.now();

  // Calculate cutoff date (2 years ago)
  const cutoffDate = new Date();
  cutoffDate.setFullYear(cutoffDate.getFullYear() - 2);

  logger.info(`Cleaning up assignments with endDate before ${cutoffDate.toISOString()}`);

  // Query assignments
  const query = db
    .collection('assignments')
    .where('endDate', '<', admin.firestore.Timestamp.fromDate(cutoffDate))
    .where('active', '==', false)
    .limit(500);

  const snapshot = await query.get();

  if (snapshot.empty) {
    logger.info('No expired assignments to delete');
    return {
      collection: 'assignments',
      deletedCount: 0,
      dryRun,
      cutoffDate,
      duration: Date.now() - startTime,
    };
  }

  // Delete in batch
  if (!dryRun) {
    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });
    await batch.commit();
  }

  const deletedCount = snapshot.size;

  logger.info(`Deleted ${deletedCount} expired assignments`, {
    collection: 'assignments',
    deletedCount,
    dryRun,
    cutoffDate: cutoffDate.toISOString(),
  });

  return {
    collection: 'assignments',
    deletedCount,
    dryRun,
    cutoffDate,
    duration: Date.now() - startTime,
  };
}

/**
 * Clean up old audit logs (1 year retention)
 *
 * Deletes audit logs older than 1 year
 */
async function cleanupOldAuditLogs(dryRun: boolean = false): Promise<DeletionResult> {
  const db = admin.firestore();
  const startTime = Date.now();

  // Calculate cutoff date (1 year ago)
  const cutoffDate = new Date();
  cutoffDate.setFullYear(cutoffDate.getFullYear() - 1);

  logger.info(`Cleaning up audit logs older than ${cutoffDate.toISOString()}`);

  // Query audit logs
  const query = db
    .collection('_audit')
    .where('timestamp', '<', admin.firestore.Timestamp.fromDate(cutoffDate))
    .limit(500);

  const snapshot = await query.get();

  if (snapshot.empty) {
    logger.info('No old audit logs to delete');
    return {
      collection: '_audit',
      deletedCount: 0,
      dryRun,
      cutoffDate,
      duration: Date.now() - startTime,
    };
  }

  // Delete in batch
  if (!dryRun) {
    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });
    await batch.commit();
  }

  const deletedCount = snapshot.size;

  logger.info(`Deleted ${deletedCount} old audit logs`, {
    collection: '_audit',
    deletedCount,
    dryRun,
    cutoffDate: cutoffDate.toISOString(),
  });

  return {
    collection: '_audit',
    deletedCount,
    dryRun,
    cutoffDate,
    duration: Date.now() - startTime,
  };
}

/**
 * Clean up expired backup metadata (30 days retention)
 *
 * Deletes backup metadata older than 30 days
 * Note: Actual backup files in Cloud Storage are cleaned up separately
 */
async function cleanupExpiredBackupMetadata(dryRun: boolean = false): Promise<DeletionResult> {
  const db = admin.firestore();
  const startTime = Date.now();

  // Calculate cutoff date (30 days ago)
  const cutoffDate = new Date();
  cutoffDate.setDate(cutoffDate.getDate() - 30);

  logger.info(`Cleaning up backup metadata older than ${cutoffDate.toISOString()}`);

  // Query backup metadata
  const query = db
    .collection('_backups')
    .where('createdAt', '<', admin.firestore.Timestamp.fromDate(cutoffDate))
    .limit(500);

  const snapshot = await query.get();

  if (snapshot.empty) {
    logger.info('No expired backup metadata to delete');
    return {
      collection: '_backups',
      deletedCount: 0,
      dryRun,
      cutoffDate,
      duration: Date.now() - startTime,
    };
  }

  // Delete in batch
  if (!dryRun) {
    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });
    await batch.commit();
  }

  const deletedCount = snapshot.size;

  logger.info(`Deleted ${deletedCount} expired backup metadata records`, {
    collection: '_backups',
    deletedCount,
    dryRun,
    cutoffDate: cutoffDate.toISOString(),
  });

  return {
    collection: '_backups',
    deletedCount,
    dryRun,
    cutoffDate,
    duration: Date.now() - startTime,
  };
}

/**
 * Clean up old probe test documents (30 days retention)
 *
 * Deletes probe test documents older than 30 days
 */
async function cleanupOldProbes(dryRun: boolean = false): Promise<DeletionResult> {
  const db = admin.firestore();
  const startTime = Date.now();

  // Calculate cutoff date (30 days ago)
  const cutoffDate = new Date();
  cutoffDate.setDate(cutoffDate.getDate() - 30);

  logger.info(`Cleaning up probe documents older than ${cutoffDate.toISOString()}`);

  // Query probes (excluding the main latency_test document)
  const query = db
    .collection('_probes')
    .where('probeAt', '<', admin.firestore.Timestamp.fromDate(cutoffDate))
    .limit(500);

  const snapshot = await query.get();

  if (snapshot.empty) {
    logger.info('No old probe documents to delete');
    return {
      collection: '_probes',
      deletedCount: 0,
      dryRun,
      cutoffDate,
      duration: Date.now() - startTime,
    };
  }

  // Delete in batch
  if (!dryRun) {
    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
      // Don't delete main latency_test document
      if (doc.id !== 'latency_test') {
        batch.delete(doc.ref);
      }
    });
    await batch.commit();
  }

  const deletedCount = snapshot.docs.filter((doc) => doc.id !== 'latency_test').length;

  logger.info(`Deleted ${deletedCount} old probe documents`, {
    collection: '_probes',
    deletedCount,
    dryRun,
    cutoffDate: cutoffDate.toISOString(),
  });

  return {
    collection: '_probes',
    deletedCount,
    dryRun,
    cutoffDate,
    duration: Date.now() - startTime,
  };
}

/**
 * Main TTL cleanup function
 *
 * Runs daily at 2:00 AM UTC via Cloud Scheduler
 */
export const dailyCleanup = onSchedule(
  {
    schedule: '0 2 * * *', // 2:00 AM UTC daily
    timeZone: 'UTC',
    region: 'us-east4',
  },
  async (_event) => {
    logger.info('Starting daily TTL cleanup...');

    const results: DeletionResult[] = [];

    try {
      // Run all cleanup tasks sequentially
      results.push(await cleanupExpiredEstimates(false));
      results.push(await cleanupExpiredAssignments(false));
      results.push(await cleanupOldAuditLogs(false));
      results.push(await cleanupExpiredBackupMetadata(false));
      results.push(await cleanupOldProbes(false));

      // Calculate summary statistics
      const totalDeleted = results.reduce((sum, r) => sum + r.deletedCount, 0);
      const totalDuration = results.reduce((sum, r) => sum + r.duration, 0);

      const summary = {
        totalDeleted,
        totalDuration,
        results,
        timestamp: new Date().toISOString(),
      };

      logger.info('Daily TTL cleanup completed', summary);

      // Alert if large number of deletions
      if (totalDeleted > 1000) {
        logger.warn(`Large cleanup: ${totalDeleted} documents deleted`, summary);
      }

      // Log final summary (schedulers must return void)
      logger.info('Daily TTL cleanup summary', summary);
    } catch (error: any) {
      logger.error('Daily TTL cleanup failed', { error: error.message, stack: error.stack });
      throw error;
    }
  }
);

/**
 * Manual cleanup function (callable)
 *
 * Allows admins to trigger cleanup manually with dry-run mode
 */
export const manualCleanup = onCall(
  { region: 'us-east4' },
  async (req: CallableRequest) => {
    const auth = req.auth;
    const data = req.data as { dryRun?: boolean; collections?: string[] };

    // Authentication check
    if (!auth) {
      throw new HttpsError('unauthenticated', 'User must be authenticated');
    }

    // Authorization check (admin only)
    const role = (auth.token as any).role;
    if (role !== 'admin') {
      throw new HttpsError('permission-denied', 'Only admins can trigger manual cleanup');
    }

    const dryRun = data.dryRun !== false; // Default to dry-run
    const collections = data.collections || ['estimates', 'assignments', 'audit', 'backups', 'probes'];

    logger.info(`Manual cleanup triggered by ${auth.uid}`, { dryRun, collections });

    const results: DeletionResult[] = [];

    try {
      // Run selected cleanup tasks
      if (collections.includes('estimates')) {
        results.push(await cleanupExpiredEstimates(dryRun));
      }
      if (collections.includes('assignments')) {
        results.push(await cleanupExpiredAssignments(dryRun));
      }
      if (collections.includes('audit')) {
        results.push(await cleanupOldAuditLogs(dryRun));
      }
      if (collections.includes('backups')) {
        results.push(await cleanupExpiredBackupMetadata(dryRun));
      }
      if (collections.includes('probes')) {
        results.push(await cleanupOldProbes(dryRun));
      }

      const totalDeleted = results.reduce((sum, r) => sum + r.deletedCount, 0);

      return {
        ok: true,
        dryRun,
        totalDeleted,
        results,
      };
    } catch (error: any) {
      logger.error('Manual cleanup failed', { error: error.message, userId: auth.uid });

      throw new HttpsError('internal', `Cleanup failed: ${error.message}`);
    }
  }
);
