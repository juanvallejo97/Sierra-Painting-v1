/**
 * Edit Time Entry - Admin-Only Function
 *
 * PURPOSE:
 * Allows admin/manager to edit time entries with proper audit trail.
 * Detects and prevents overlapping shifts for the same worker.
 *
 * SECURITY:
 * - Requires admin or manager role
 * - Enforces company isolation
 * - Forbids editing invoiced/approved entries (unless force flag + audit)
 * - Records all edits with before/after snapshot
 *
 * OVERLAP DETECTION:
 * - Checks for other entries by same user with overlapping [clockInAt, clockOutAt]
 * - Tags with "overlap" exception if detected
 *
 * AUDIT TRAIL:
 * - Creates audit record with editedBy, editReason, before/after
 * - Resets approval status if material changes (times)
 */

import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v2/https";
import { ensureMutable } from "./utils/schema_normalizer";

/**
 * Edit Time Entry Callable Function
 *
 * @param timeEntryId - ID of time entry to edit
 * @param editReason - Required reason for edit (audit trail)
 * @param clockInAt - Optional new clock-in time
 * @param clockOutAt - Optional new clock-out time
 * @param notes - Optional notes update
 * @param force - Force edit even if invoiced (admin only, creates audit flag)
 */
export const editTimeEntry = functions.onCall({ region: 'us-east4' }, async (req) => {
  const {timeEntryId, editReason, clockInAt, clockOutAt, notes, force} = req.data || {};
  const uid = req.auth?.uid;
  const role = req.auth?.token?.role;
  const companyId = req.auth?.token?.company_id;

  // 1) Authentication & Authorization
  if (!uid) {
    throw new functions.HttpsError("unauthenticated", "Sign in required");
  }

  if (!role || !["admin", "manager"].includes(role)) {
    throw new functions.HttpsError(
      "permission-denied",
      "Only admin or manager can edit time entries"
    );
  }

  if (!companyId) {
    throw new functions.HttpsError("permission-denied", "Missing company_id claim");
  }

  // 2) Validate parameters
  if (!timeEntryId || !editReason) {
    throw new functions.HttpsError(
      "invalid-argument",
      "Missing required parameters: timeEntryId, editReason"
    );
  }

  if (editReason.length < 3 || editReason.length > 500) {
    throw new functions.HttpsError(
      "invalid-argument",
      "editReason must be between 3 and 500 characters"
    );
  }

  if (!clockInAt && !clockOutAt && !notes) {
    throw new functions.HttpsError("invalid-argument", "No changes specified");
  }

  const db = admin.firestore();

  // 3) Fetch and validate entry
  const entryRef = db.doc(`timeEntries/${timeEntryId}`);
  const entrySnap = await entryRef.get();

  if (!entrySnap.exists) {
    throw new functions.HttpsError("not-found", "Time entry not found");
  }

  const entry = entrySnap.data()!;

  // Company isolation
  if (entry.companyId !== companyId) {
    throw new functions.HttpsError("permission-denied", "Entry belongs to different company");
  }

  // Immutability guard (unless force flag for admin)
  if (!force) {
    // ensureMutable throws if approved or invoiced
    ensureMutable(entry);
  } else {
    // Force edit only allowed for admins
    if (role !== "admin") {
      throw new functions.HttpsError(
        "permission-denied",
        "Only admin can force-edit approved/invoiced entries"
      );
    }
  }

  // 4) Parse and validate new timestamps
  let newClockInAt = entry.clockInAt.toDate();
  let newClockOutAt = entry.clockOutAt?.toDate() || null;

  if (clockInAt) {
    newClockInAt = new Date(clockInAt);
    if (isNaN(newClockInAt.getTime())) {
      throw new functions.HttpsError("invalid-argument", "Invalid clockInAt timestamp");
    }
  }

  if (clockOutAt) {
    newClockOutAt = new Date(clockOutAt);
    if (isNaN(newClockOutAt.getTime())) {
      throw new functions.HttpsError("invalid-argument", "Invalid clockOutAt timestamp");
    }
  }

  // Validate clock-out is after clock-in
  if (newClockOutAt && newClockOutAt <= newClockInAt) {
    throw new functions.HttpsError(
      "invalid-argument",
      "Clock-out must be after clock-in"
    );
  }

  // Validate shift duration (max 24 hours)
  if (newClockOutAt) {
    const durationHours = (newClockOutAt.getTime() - newClockInAt.getTime()) / (1000 * 60 * 60);
    if (durationHours > 24) {
      throw new functions.HttpsError(
        "invalid-argument",
        "Shift duration cannot exceed 24 hours"
      );
    }
  }

  // 5) Check for overlaps with other entries by same user
  const hasTimeChange = clockInAt || clockOutAt;
  let hasOverlap = false;

  if (hasTimeChange && newClockOutAt) {
    const overlapQuery = await db
      .collection("timeEntries")
      .where("companyId", "==", companyId)
      .where("userId", "==", entry.userId)
      .where("clockInAt", "<", admin.firestore.Timestamp.fromDate(newClockOutAt))
      .get();

    for (const doc of overlapQuery.docs) {
      if (doc.id === timeEntryId) continue; // Skip self

      const other = doc.data();
      const otherClockOut = other.clockOutAt?.toDate();

      // Check if ranges overlap
      if (otherClockOut && otherClockOut > newClockInAt) {
        hasOverlap = true;
        break;
      }
    }
  }

  // 6) Build audit record (before/after snapshot)
  const changes: Record<string, any> = {};

  if (clockInAt) {
    changes.clockInAt = {
      before: entry.clockInAt.toDate().toISOString(),
      after: newClockInAt.toISOString(),
    };
  }

  if (clockOutAt) {
    changes.clockOutAt = {
      before: entry.clockOutAt?.toDate()?.toISOString() || null,
      after: newClockOutAt?.toISOString() || null,
    };
  }

  if (notes !== undefined) {
    changes.notes = {
      before: entry.notes || null,
      after: notes,
    };
  }

  const auditRecord = {
    editedBy: uid,
    editedAt: admin.firestore.FieldValue.serverTimestamp(),
    editReason,
    changes,
    forceEdit: force || false,
    invoiced: !!entry.invoiceId,
  };

  // 7) Prepare updates
  const updates: Record<string, any> = {
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    auditLog: admin.firestore.FieldValue.arrayUnion(auditRecord),
  };

  if (clockInAt) {
    updates.clockInAt = admin.firestore.Timestamp.fromDate(newClockInAt);
  }

  if (clockOutAt) {
    updates.clockOutAt = admin.firestore.Timestamp.fromDate(newClockOutAt!);
  }

  if (notes !== undefined) {
    updates.notes = notes;
  }

  // Reset approval if material changes (times changed)
  if (hasTimeChange && entry.approved) {
    updates.approved = false;
    updates.approvedBy = null;
    updates.approvedAt = null;
    updates.requiresReapproval = true;
  }

  // Add overlap exception tag
  if (hasOverlap) {
    updates.exceptionTags = admin.firestore.FieldValue.arrayUnion("overlap");
  }

  // 8) Apply updates
  await entryRef.update(updates);

  // 9) Write separate audit document for long-term retention
  await db.collection("audits").add({
    type: "time_entry_edit",
    entityType: "timeEntry",
    entityId: timeEntryId,
    companyId,
    ...auditRecord,
  });

  return {
    ok: true,
    hasOverlap,
    requiresReapproval: hasTimeChange && entry.approved,
  };
});
