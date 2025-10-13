/**
 * Bulk Approve Time Entries
 *
 * PURPOSE:
 * Admin callable to approve multiple time entries at once.
 * Used in Admin Review workflow for efficient exception handling.
 *
 * SECURITY:
 * - Admin-only (checks custom claim)
 * - Company scope validation (entries must belong to admin's company)
 * - Idempotent (safe to call multiple times)
 *
 * AUDIT:
 * - Logs all approvals with adminId, companyId, entryIds
 * - Writes audit trail for each approved entry
 *
 * USAGE:
 * ```typescript
 * const result = await functions.httpsCallable('bulkApproveTimeEntries')({
 *   entryIds: ['entry1', 'entry2', 'entry3'],
 * });
 * // Returns: { approved: 3, failed: 0, errors: [] }
 * ```
 */

import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';

/**
 * Bulk approve request
 */
interface BulkApproveRequest {
  entryIds: string[];
}

/**
 * Bulk approve response
 */
interface BulkApproveResponse {
  approved: number;
  failed: number;
  errors: Array<{entryId: string; error: string}>;
  timestamp: string;
}

/**
 * Bulk Approve Time Entries Callable
 *
 * Approves multiple time entries in a single atomic operation.
 * Sets approved=true, records approvedBy/approvedAt, writes audit trail.
 *
 * @param entryIds - Array of time entry IDs to approve (max 500)
 * @returns {approved, failed, errors, timestamp}
 */
export const bulkApproveTimeEntries = functions.onCall(
  { region: 'us-east4' },
  async (request) => {
    const { entryIds } = request.data as BulkApproveRequest;
    const adminUid = request.auth?.uid;
    const adminCompanyId = request.auth?.token.companyId;
    const isAdmin = request.auth?.token.admin === true;

    // Authentication check
    if (!request.auth) {
      throw new functions.HttpsError(
        'unauthenticated',
        'Must be authenticated to approve time entries'
      );
    }

    // Admin authorization check
    if (!isAdmin) {
      throw new functions.HttpsError(
        'permission-denied',
        'Must be admin to approve time entries'
      );
    }

    // Validate input
    if (!entryIds || !Array.isArray(entryIds) || entryIds.length === 0) {
      throw new functions.HttpsError(
        'invalid-argument',
        'entryIds must be a non-empty array'
      );
    }

    // Limit batch size to prevent timeouts
    if (entryIds.length > 500) {
      throw new functions.HttpsError(
        'invalid-argument',
        'Maximum 500 entries per batch. Split into multiple requests.'
      );
    }

    logger.info('bulkApproveTimeEntries: Request received', {
      adminUid,
      adminCompanyId,
      entryCount: entryIds.length,
    });

    const db = admin.firestore();
    const errors: Array<{entryId: string; error: string}> = [];
    let approved = 0;
    let failed = 0;

    // Process in batches (Firestore batch limit is 500 operations)
    const batchSize = 500;
    for (let i = 0; i < entryIds.length; i += batchSize) {
      const batchEntryIds = entryIds.slice(i, i + batchSize);
      const batch = db.batch();

      for (const entryId of batchEntryIds) {
        try {
          const entryRef = db.collection('timeEntries').doc(entryId);
          const entrySnap = await entryRef.get();

          // Entry exists?
          if (!entrySnap.exists) {
            errors.push({ entryId, error: 'Entry not found' });
            failed++;
            continue;
          }

          const entry = entrySnap.data()!;

          // Company scope check
          if (entry.companyId !== adminCompanyId) {
            errors.push({ entryId, error: 'Entry belongs to different company' });
            failed++;
            logger.warn('bulkApproveTimeEntries: Cross-company attempt blocked', {
              adminUid,
              adminCompanyId,
              entryCompanyId: entry.companyId,
              entryId,
            });
            continue;
          }

          // Idempotent: if already approved, skip
          if (entry.approved === true) {
            logger.info('bulkApproveTimeEntries: Entry already approved (idempotent)', {
              entryId,
              adminUid,
            });
            approved++; // Count as success for idempotency
            continue;
          }

          // Approve entry
          batch.update(entryRef, {
            approved: true,
            approvedBy: adminUid,
            approvedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Write audit trail
          const auditRef = db.collection('auditLog').doc();
          batch.set(auditRef, {
            action: 'approve_time_entry',
            actorUid: adminUid,
            companyId: adminCompanyId,
            targetType: 'timeEntry',
            targetId: entryId,
            before: {
              approved: entry.approved ?? false,
            },
            after: {
              approved: true,
            },
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          });

          approved++;
        } catch (error: any) {
          errors.push({
            entryId,
            error: error.message || 'Unknown error',
          });
          failed++;
          logger.error('bulkApproveTimeEntries: Error processing entry', {
            entryId,
            adminUid,
            error: error.message,
          });
        }
      }

      // Commit batch
      try {
        await batch.commit();
        logger.info('bulkApproveTimeEntries: Batch committed', {
          batchSize: batchEntryIds.length,
          approved,
          failed,
        });
      } catch (error: any) {
        logger.error('bulkApproveTimeEntries: Batch commit failed', {
          error: error.message,
          batchSize: batchEntryIds.length,
        });
        throw new functions.HttpsError(
          'internal',
          `Batch commit failed: ${error.message}`
        );
      }
    }

    const response: BulkApproveResponse = {
      approved,
      failed,
      errors,
      timestamp: new Date().toISOString(),
    };

    logger.info('bulkApproveTimeEntries: Complete', {
      adminUid,
      adminCompanyId,
      approved,
      failed,
      errorCount: errors.length,
    });

    return response;
  }
);
