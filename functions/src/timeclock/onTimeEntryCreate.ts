/**
 * Cloud Function: onTimeEntryCreate
 *
 * PURPOSE:
 * Triggered when a new time entry is created in Firestore.
 * Automatically flags entries that need admin review based on:
 * - Offline origin
 * - Geofence violations
 * - GPS missing
 * - 24-hour fraud control
 *
 * SECURITY:
 * - Runs with admin privileges (server-side only)
 * - Cannot be triggered by client
 * - Validates all entry fields
 *
 * HAIKU TODO:
 * - Implement fraud detection logic
 * - Add telemetry events
 * - Send admin notifications for flagged entries
 */

import * as functions from "firebase-functions/v2";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";

interface TimeEntryData {
  clientEventId: string;
  companyId: string;
  workerId: string;
  jobId: string;
  clockIn: Timestamp;
  clockOut?: Timestamp;
  origin: "online" | "offline";
  needsReview: boolean;
  clockInGeofenceValid: boolean;
  clockOutGeofenceValid?: boolean;
  gpsMissing: boolean;
  deviceId?: string;
  status: "active" | "pending" | "approved" | "flagged" | "disputed";
}

/**
 * Firestore trigger: onCreate for time_entries
 *
 * HAIKU TODO: Implement the following checks:
 * 1. If origin === 'offline', set needsReview = true
 * 2. If clockInGeofenceValid === false, set needsReview = true
 * 3. If gpsMissing === true, set needsReview = true
 * 4. If entry duration > 24 hours, reject/flag
 * 5. Check for duplicate clientEventId (idempotency)
 * 6. Send telemetry event: time_entry_created
 * 7. If needsReview changed to true, send admin notification
 */
export const onTimeEntryCreate = onDocumentCreated(
  {
    document: "companies/{companyId}/time_entries/{entryId}",
    region: "us-east4",
    memory: "256MiB",
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      functions.logger.warn("No data in time entry create event");
      return;
    }

    const entryData = snapshot.data() as TimeEntryData;
    const { companyId } = event.params;
    const entryId = event.params.entryId;

    functions.logger.info("Time entry created", {
      companyId,
      entryId,
      workerId: entryData.workerId,
      origin: entryData.origin,
    });

    // Initialize flags object
    const flags: {
      needsReview: boolean;
      flagReasons: string[];
    } = {
      needsReview: entryData.needsReview || false,
      flagReasons: [],
    };

    // Check if offline origin
    if (entryData.origin === "offline") {
      flags.needsReview = true;
      flags.flagReasons.push("offline_origin");
    }

    // Check geofence violations
    if (!entryData.clockInGeofenceValid) {
      flags.needsReview = true;
      flags.flagReasons.push("geofence_violation_clock_in");
    }

    // Check GPS missing
    if (entryData.gpsMissing) {
      flags.needsReview = true;
      flags.flagReasons.push("gps_missing");
    }

    // Check for 24+ hour duration (fraud control)
    const now = new Date();
    const clockInDate = entryData.clockIn.toDate();
    const durationHours = (now.getTime() - clockInDate.getTime()) / (1000 * 60 * 60);
    if (durationHours >= 24) {
      flags.needsReview = true;
      flags.flagReasons.push("exceeds_24_hours");
    }

    // Check for duplicate clientEventId (idempotency)
    const db = getFirestore();
    const duplicateQuery = await db
      .collection(`companies/${companyId}/time_entries`)
      .where("clientEventId", "==", entryData.clientEventId)
      .where("__name__", "!=", entryId)
      .limit(1)
      .get();

    if (!duplicateQuery.empty) {
      functions.logger.warn("Duplicate time entry detected", {
        entryId,
        clientEventId: entryData.clientEventId,
      });
      // Mark as duplicate, don't create
      await snapshot.ref.update({
        status: "flagged",
        needsReview: true,
        flagReasons: FieldValue.arrayUnion("duplicate_entry"),
      });
      return;
    }

    // Update entry if flags changed
    if (flags.needsReview && flags.flagReasons.length > 0) {
      await snapshot.ref.update({
        needsReview: true,
        flagReasons: flags.flagReasons,
        status: "flagged",
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    // Send telemetry event
    logEvent("time_entry_created", {
      companyId,
      workerId: entryData.workerId,
      origin: entryData.origin,
      needsReview: flags.needsReview,
      flagReasons: flags.flagReasons,
    });

    // Send admin notification if flagged
    if (flags.needsReview) {
      await sendAdminNotification(companyId, {
        type: "time_entry_flagged",
        entryId,
        workerId: entryData.workerId,
        reasons: flags.flagReasons,
      });
    }

    functions.logger.info("Time entry processing complete", {
      entryId,
      needsReview: flags.needsReview,
      flagReasons: flags.flagReasons,
    });
  }
);

/**
 * Send admin notification when time entry needs review
 * Creates Firestore notification document for admin dashboard display
 */
async function sendAdminNotification(
  companyId: string,
  notification: {
    type: string;
    entryId: string;
    workerId: string;
    reasons: string[];
  }
): Promise<void> {
  try {
    const db = getFirestore();

    // Create notification document for admins
    await db.collection(`companies/${companyId}/notifications`).add({
      type: notification.type,
      targetRole: "admin",
      title: "Time Entry Flagged for Review",
      message: `Worker time entry needs review (${notification.reasons.join(", ")})`,
      data: {
        entryId: notification.entryId,
        workerId: notification.workerId,
        reasons: notification.reasons,
      },
      read: false,
      createdAt: FieldValue.serverTimestamp(),
      expiresAt: Timestamp.fromDate(
        new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // 30 days TTL
      ),
    });

    functions.logger.info("Admin notification created", {
      companyId,
      entryId: notification.entryId,
      reasons: notification.reasons,
    });
  } catch (error) {
    functions.logger.error("Failed to create admin notification", {
      error: String(error),
      companyId,
      entryId: notification.entryId,
    });
  }
}

/**
 * Log telemetry events for monitoring and analytics
 */
function logEvent(eventName: string, params: Record<string, unknown>): void {
  // Log to Cloud Functions logs (visible in Firebase Console > Logs)
  functions.logger.info(`telemetry_event: ${eventName}`, params);
}
