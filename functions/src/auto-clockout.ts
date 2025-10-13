/**
 * Auto Clock-Out Scheduled Function
 *
 * PURPOSE:
 * Automatically clock out workers who have been clocked in for >12 hours.
 * Prevents runaway time entries from forgotten clock-outs.
 *
 * SCHEDULE:
 * Runs every 15 minutes
 *
 * LOGIC:
 * 1. Query timeEntries where clockOutAt==null && clockInAt < now-12h
 * 2. For each entry:
 *    - Set clockOutAt = clockInAt + 12h (not current time, to cap at 12h)
 *    - Set autoClockOut = true
 *    - Add exceptionTags = ["auto_clockout", "exceeds_12h"]
 * 3. Enqueue notification to worker and admin
 *
 * AUDIT:
 * All auto clock-outs are logged with reason and flagged for Admin Review.
 */

import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v2/scheduler";
import * as callableFunctions from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

/**
 * Core auto clock-out logic (shared by scheduler and admin callable)
 *
 * @param dryRun - If true, log would-change set without committing
 * @returns {processed: number, entries: [...]} - Count and list of processed entries
 */
export async function runAutoClockOutOnce(dryRun: boolean = false): Promise<{processed: number; entries: Array<{entryId: string; userId: string; jobId: string; clockInAt: string; wouldClockOutAt: string}>}> {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();
  const twelveHoursAgo = new Date(now.toDate().getTime() - 12 * 60 * 60 * 1000);

  logger.info("runAutoClockOutOnce: Starting auto clock-out check", {
    now: now.toDate().toISOString(),
    cutoff: twelveHoursAgo.toISOString(),
    dryRun,
  });

  try {
    // Query entries clocked in >12 hours ago with no clock out
    const overdueEntries = await db
      .collection("timeEntries")
      .where("clockOutAt", "==", null)
      .where("clockInAt", "<", admin.firestore.Timestamp.fromDate(twelveHoursAgo))
      .limit(100) // Process in batches to avoid timeout
      .get();

    if (overdueEntries.empty) {
      logger.info("runAutoClockOutOnce: No overdue entries found");
      return {processed: 0, entries: []};
    }

    logger.info(`runAutoClockOutOnce: Found ${overdueEntries.size} overdue entries`, {
      count: overdueEntries.size,
      dryRun,
    });

    // Process each overdue entry
    const batch = db.batch();
    let processed = 0;
    const entriesProcessed: Array<{entryId: string; userId: string; jobId: string; clockInAt: string; wouldClockOutAt: string}> = [];

    for (const doc of overdueEntries.docs) {
      const entry = doc.data();
      const clockInAt = entry.clockInAt.toDate();

      // Set clockOutAt to clockInAt + 12 hours (not current time)
      const clockOutAt = new Date(clockInAt.getTime() + 12 * 60 * 60 * 1000);

      logger.info(dryRun ? "runAutoClockOutOnce: [DRY-RUN] Would process entry" : "runAutoClockOutOnce: Processing entry", {
        entryId: doc.id,
        userId: entry.userId,
        jobId: entry.jobId,
        companyId: entry.companyId,
        clockInAt: clockInAt.toISOString(),
        wouldClockOutAt: clockOutAt.toISOString(),
        durationHours: ((clockOutAt.getTime() - clockInAt.getTime()) / (1000 * 60 * 60)).toFixed(1),
        dryRun,
      });

      if (!dryRun) {
        // Update entry with auto clock-out
        batch.update(doc.ref, {
          clockOutAt: admin.firestore.Timestamp.fromDate(clockOutAt),
          autoClockOut: true,
          exceptionTags: admin.firestore.FieldValue.arrayUnion(
            "auto_clockout",
            "exceeds_12h"
          ),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          autoClockOutReason: "Exceeded 12 hour maximum shift",
        });
      }

      processed++;
      entriesProcessed.push({
        entryId: doc.id,
        userId: entry.userId,
        jobId: entry.jobId,
        clockInAt: clockInAt.toISOString(),
        wouldClockOutAt: clockOutAt.toISOString(),
      });

      // TODO: Enqueue notification to worker and admin
      // await notificationQueue.enqueue({
      //   type: 'auto_clockout',
      //   userId: entry.userId,
      //   entryId: doc.id,
      //   message: 'You were automatically clocked out after 12 hours',
      // });
    }

    // Commit batch (skip if dry-run)
    if (!dryRun) {
      await batch.commit();
      logger.info(`runAutoClockOutOnce: Successfully processed ${processed} entries`);
    } else {
      logger.info(`runAutoClockOutOnce: [DRY-RUN] Would process ${processed} entries (no changes committed)`, {
        count: processed,
      });
    }

    return {processed, entries: entriesProcessed};
  } catch (error: any) {
    // Gracefully handle missing index
    if (error?.code === 9 || String(error?.message || '').includes('FAILED_PRECONDITION') || String(error?.message || '').includes('index')) {
      logger.warn("runAutoClockOutOnce: Missing Firestore index", {
        hint: "Run: firebase deploy --only firestore:indexes",
        error: error?.message,
      });
      return {processed: 0, entries: []}; // Exit gracefully, don't crash
    }

    logger.error("runAutoClockOutOnce: Error processing auto clock-outs", {error});
    throw error;
  }
}

/**
 * Auto Clock-Out Scheduled Function
 *
 * Runs every 15 minutes to check for entries exceeding 12 hours.
 */
export const autoClockOut = functions.onSchedule(
  {
    schedule: "*/15 * * * *", // Every 15 minutes
    timeZone: "America/New_York",
    region: "us-east4",
  },
  async () => {
    await runAutoClockOutOnce();
  }
);

/**
 * Admin-only manual trigger for auto clock-out
 *
 * Supports dry-run mode for testing without side effects.
 * Uses a concurrency lock to prevent overlapping runs.
 *
 * @param dryRun - If true, log would-change set without committing
 * @returns {success, processed, entries[], timestamp, dryRun}
 */
export const adminAutoClockOutOnce = callableFunctions.onCall(
  { region: "us-east4" },
  async (request) => {
    const {dryRun = false} = request.data || {};
    const db = admin.firestore();

    // Check if user is authenticated
    if (!request.auth) {
      throw new callableFunctions.HttpsError(
        "unauthenticated",
        "Must be authenticated to trigger auto clock-out"
      );
    }

    // Check if user is admin (has admin custom claim)
    const isAdmin = request.auth.token.admin === true;
    if (!isAdmin) {
      throw new callableFunctions.HttpsError(
        "permission-denied",
        "Must be admin to trigger auto clock-out"
      );
    }

    logger.info("adminAutoClockOutOnce: Manual trigger by admin", {
      adminId: request.auth.uid,
      dryRun,
    });

    // Concurrency guard: acquire lock
    const lockRef = db.doc("_system/autoClockOutLock");
    const lockId = `${request.auth.uid}-${Date.now()}`;
    const lockExpiry = new Date(Date.now() + 5 * 60 * 1000); // 5-minute lease

    try {
      // Try to acquire lock (skip in dry-run mode)
      if (!dryRun) {
        await db.runTransaction(async (tx) => {
          const lockSnap = await tx.get(lockRef);

          if (lockSnap.exists) {
            const lock = lockSnap.data()!;
            const expiresAt = lock.expiresAt?.toDate();

            // Check if lock is still valid
            if (expiresAt && expiresAt > new Date()) {
              throw new callableFunctions.HttpsError(
                "resource-exhausted",
                `Auto clock-out is already running. Try again after ${expiresAt.toISOString()}`
              );
            }
          }

          // Acquire or renew lock
          tx.set(lockRef, {
            lockId,
            acquiredBy: request.auth!.uid,
            acquiredAt: admin.firestore.FieldValue.serverTimestamp(),
            expiresAt: admin.firestore.Timestamp.fromDate(lockExpiry),
          });
        });

        logger.info("adminAutoClockOutOnce: Lock acquired", {
          lockId,
          adminId: request.auth.uid,
        });
      }

      // Run auto clock-out
      const result = await runAutoClockOutOnce(dryRun);

      // Release lock (skip in dry-run mode)
      if (!dryRun) {
        await lockRef.delete();
        logger.info("adminAutoClockOutOnce: Lock released", {lockId});
      }

      return {
        success: true,
        processed: result.processed,
        entries: result.entries,
        timestamp: new Date().toISOString(),
        dryRun,
      };
    } catch (error: any) {
      // Release lock on error (if acquired)
      if (!dryRun) {
        try {
          const lockSnap = await lockRef.get();
          if (lockSnap.exists && lockSnap.data()?.lockId === lockId) {
            await lockRef.delete();
            logger.info("adminAutoClockOutOnce: Lock released after error", {lockId});
          }
        } catch (cleanupError) {
          logger.warn("adminAutoClockOutOnce: Failed to release lock after error", {lockId, cleanupError});
        }
      }

      throw error;
    }
  }
);
