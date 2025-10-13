/**
 * Timeclock Cloud Functions
 *
 * Version: 2.0 (Canonical Schema - Option B Stability Patch)
 * Last Updated: 2025-10-12
 *
 * PURPOSE:
 * Geofence-enforced time tracking for workers at job sites.
 * Clients post clockEvents; these functions validate location and create timeEntries.
 *
 * FLOW:
 * 1. Client calls clockIn with jobId, location, clientEventId
 * 2. Function validates:
 *    - User is assigned to the job
 *    - Location is within geofence (haversine distance)
 *    - No active time entry exists
 *    - Idempotency via clientEventId
 * 3. Function creates timeEntry with server timestamp
 *
 * GEOFENCE LOGIC:
 * - Base radius: job.geofence.radiusM (default 100m)
 * - Minimum radius: 75m (safety guard)
 * - Maximum radius: 250m (prevents overly permissive zones)
 * - Accuracy buffer: max(accuracy, 15m) added to radius
 *
 * SECURITY:
 * - Only authenticated users can call
 * - Assignment validation ensures user is assigned to job
 * - Company isolation enforced via assignment check
 *
 * IMPORTANT:
 * - Uses canonical v2.0 schemas (see docs/schemas/)
 * - Collection: time_entries (NOT timeEntries)
 * - Job geofence: nested object {lat, lng, radiusM}
 * - Field names: clockInGeofenceValid, clockInLocation, etc.
 */

import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {normalizeJob} from "./types";
import {ensureAppCheck} from "./middleware/ensureAppCheck";
import {validateEventIdTTL} from "./middleware/eventIdValidator";

/**
 * Haversine distance calculation
 * Returns distance in meters between two lat/lng points
 */
const HAVERSINE = (a: {lat: number; lng: number}, b: {lat: number; lng: number}): number => {
  const toRad = (x: number) => x * Math.PI / 180;
  const R = 6371000; // Earth radius in meters
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const s1 = Math.sin(dLat / 2);
  const s2 = Math.sin(dLng / 2);
  const aa = s1 * s1 + Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * s2 * s2;
  return 2 * R * Math.asin(Math.sqrt(aa));
};

/**
 * Clock In - Create time entry after geofence validation
 *
 * RACE-PROOF: Uses Firestore transaction to atomically check for active entries
 * and create new entry, preventing double clock-ins from concurrent requests.
 *
 * @param jobId - Job site ID to clock into
 * @param lat - Current latitude
 * @param lng - Current longitude
 * @param accuracy - GPS accuracy in meters (optional)
 * @param clientEventId - Unique ID for idempotency
 * @returns {id: string, ok: boolean} - Created time entry ID
 */
export const clockIn = functions.onCall({
  region: 'us-east4',
  minInstances: 1,
  concurrency: 20,
  timeoutSeconds: 10,
  memory: '256MiB',
}, async (req) => {
  ensureAppCheck(req);

  const {jobId, lat, lng, accuracy, clientEventId, deviceId} = req.data || {};
  const uid = req.auth?.uid;

  logger.info("clockIn: Request received", {
    uid,
    jobId,
    clientEventId,
    deviceId: deviceId ?? "unknown",
    hasAuth: !!req.auth,
  });

  if (!uid) {
    logger.warn("clockIn: Unauthenticated request", {clientEventId});
    throw new functions.HttpsError("unauthenticated", "Sign in required");
  }

  // Validate required parameters
  if (!jobId || lat === undefined || lng === undefined || !clientEventId) {
    logger.warn("clockIn: Missing required parameters", {uid, jobId, clientEventId});
    throw new functions.HttpsError("invalid-argument", "Missing required parameters: jobId, lat, lng, clientEventId");
  }

  // Validate clientEventId length (prevent storage abuse)
  if (clientEventId.length > 64) {
    throw new functions.HttpsError("invalid-argument", "clientEventId must be ≤64 characters");
  }

  // Validate clientEventId TTL (prevent replay attacks)
  validateEventIdTTL(clientEventId, 'clockIn');

  // Validate coordinates
  if (lat < -90 || lat > 90 || isNaN(lat)) {
    throw new functions.HttpsError("invalid-argument", "Invalid latitude: must be between -90 and 90");
  }
  if (lng < -180 || lng > 180 || isNaN(lng)) {
    throw new functions.HttpsError("invalid-argument", "Invalid longitude: must be between -180 and 180");
  }

  // Validate GPS accuracy (prevent false negatives from poor GPS)
  if (accuracy && (accuracy < 0 || accuracy > 2000 || isNaN(accuracy))) {
    throw new functions.HttpsError("invalid-argument", "Invalid accuracy: must be between 0 and 2000 meters");
  }
  // STAGING: Relaxed GPS threshold for indoor/testing scenarios (PRODUCTION should use 50m)
  if (accuracy && accuracy > 200) {
    throw new functions.HttpsError(
      "failed-precondition",
      "GPS accuracy too low. Please wait for better signal (current: " + accuracy.toFixed(0) + "m)"
    );
  }

  const db = admin.firestore();

  // 1) Idempotency check FIRST (before expensive operations)
  const existingEntryQuery = await db.collection("time_entries")
    .where("userId", "==", uid)
    .where("clientEventId", "==", clientEventId)
    .limit(1)
    .get();

  if (!existingEntryQuery.empty) {
    const entryId = existingEntryQuery.docs[0].id;
    logger.info("clockIn: Idempotent replay detected", {
      uid,
      jobId,
      entryId,
      clientEventId,
      deviceId: deviceId ?? "unknown",
    });
    return {id: entryId, ok: true};
  }

  // 2) Fetch job document and normalize to canonical schema
  const jobSnap = await db.doc(`jobs/${jobId}`).get();
  if (!jobSnap.exists) {
    throw new functions.HttpsError("not-found", "Job not found");
  }

  // Normalize job to handle both legacy and canonical formats
  const job = normalizeJob(jobSnap.data() as any);

  // 3) Verify user is assigned to this job with active time window
  const assignmentQuery = await db.collection("assignments")
    .where("companyId", "==", job.companyId)
    .where("jobId", "==", jobId)
    .where("userId", "==", uid)
    .where("active", "==", true)
    .limit(1)
    .get();

  if (assignmentQuery.empty) {
    throw new functions.HttpsError("permission-denied", "Not assigned to this job");
  }

  // Check assignment time window if startDate/endDate are set
  const assignment = assignmentQuery.docs[0].data();
  const now = new Date();

  if (assignment.startDate) {
    const startDate = assignment.startDate.toDate();
    if (now < startDate) {
      throw new functions.HttpsError(
        "failed-precondition",
        `Assignment not active yet. Starts: ${startDate.toLocaleDateString()}`
      );
    }
  }

  if (assignment.endDate) {
    const endDate = assignment.endDate.toDate();
    if (now > endDate) {
      throw new functions.HttpsError(
        "failed-precondition",
        `Assignment expired. Ended: ${endDate.toLocaleDateString()}`
      );
    }
  }

  // 4) Distance check - adaptive radius with safety guards
  // CRITICAL: Use nested geofence structure (canonical v2.0 schema)
  const distance = HAVERSINE(
    {lat: job.geofence.lat, lng: job.geofence.lng},
    {lat, lng}
  );

  // Adaptive radius: minimum 75m, use job.geofence.radiusM if set, cap at 250m
  const baseRadius = Math.max(75, Math.min(job.geofence.radiusM ?? 100, 250));
  const accuracyBuffer = Math.max(accuracy ?? 0, 15);
  const effectiveRadius = baseRadius + accuracyBuffer;

  // STAGING: Skip geofence enforcement if disabled (for remote testing)
  const disableGeofence = process.env.DISABLE_GEOFENCE === "true";

  logger.info("clockIn: Geofence check", {
    uid,
    jobId,
    companyId: job.companyId,
    distanceM: Math.round(distance * 10) / 10,
    radiusM: baseRadius,
    accuracyM: accuracy ?? null,
    effectiveRadiusM: Math.round(effectiveRadius * 10) / 10,
    decision: disableGeofence ? "ALLOW (geofence disabled)" : (distance <= effectiveRadius ? "ALLOW" : "DENY"),
    geofenceDisabled: disableGeofence,
    clientEventId,
    deviceId: deviceId ?? "unknown",
  });

  if (!disableGeofence && distance > effectiveRadius) {
    throw new functions.HttpsError(
      "failed-precondition",
      `Outside geofence: ${distance.toFixed(1)}m from job site (max ${effectiveRadius.toFixed(1)}m)`
    );
  }

  // 5) TRANSACTIONAL: Check for active entry and create new entry atomically
  const entryId = await db.runTransaction(async (tx) => {
    // Check for active entries within transaction
    const activeQuery = db.collection("time_entries")
      .where("companyId", "==", job.companyId)
      .where("userId", "==", uid)
      .where("clockOutAt", "==", null)
      .limit(1);

    const activeSnap = await tx.get(activeQuery);

    if (!activeSnap.empty) {
      throw new functions.HttpsError("failed-precondition", "Already clocked in to a job");
    }

    // Create new entry within transaction using canonical v2.0 schema
    const entryRef = db.collection("time_entries").doc();
    tx.set(entryRef, {
      entryId: entryRef.id,
      companyId: job.companyId,
      userId: uid,
      jobId,
      status: "active", // Required for UI to detect active entry
      clockInAt: admin.firestore.FieldValue.serverTimestamp(),
      clockInLoc: new admin.firestore.GeoPoint(lat, lng), // Fixed: clockInLoc not clockInLocation
      clockInGeofenceValid: true, // Canonical field name
      clockOutAt: null,
      clockOutLoc: null, // Fixed: clockOutLoc not clockOutLocation
      clockOutGeofenceValid: null,
      notes: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      // Audit fields (non-canonical but useful for debugging)
      radiusUsedM: baseRadius,
      accuracyAtInM: accuracy ?? null,
      distanceAtInM: distance,
      clientEventId,
      deviceId: deviceId ?? null,
    });

    return entryRef.id;
  });

  logger.info("clockIn: Success", {
    uid,
    jobId,
    companyId: job.companyId,
    entryId,
    distanceM: Math.round(distance * 10) / 10,
    radiusM: baseRadius,
    accuracyM: accuracy ?? null,
    clientEventId,
    deviceId: deviceId ?? "unknown",
  });

  return {id: entryId, ok: true};
});

/**
 * Clock Out - Complete active time entry after geofence validation
 *
 * Records geoOkOut flag and exception tagging for Admin Review.
 * If outside geofence, allows clock-out but flags for review.
 *
 * @param timeEntryId - ID of active time entry to close
 * @param lat - Current latitude
 * @param lng - Current longitude
 * @param accuracy - GPS accuracy in meters (optional)
 * @returns {ok: boolean, warning?: string} - Success status with optional warning
 */
export const clockOut = functions.onCall({
  region: 'us-east4',
  minInstances: 1,
  concurrency: 20,
  timeoutSeconds: 10,
  memory: '256MiB',
}, async (req) => {
  ensureAppCheck(req);

  const {timeEntryId, lat, lng, accuracy, clientEventId, deviceId} = req.data || {};
  const uid = req.auth?.uid;

  logger.info("clockOut: Request received", {
    uid,
    timeEntryId,
    clientEventId: clientEventId ?? "missing",
    deviceId: deviceId ?? "unknown",
    hasAuth: !!req.auth,
  });

  if (!uid) {
    logger.warn("clockOut: Unauthenticated request", {timeEntryId});
    throw new functions.HttpsError("unauthenticated", "Sign in required");
  }

  // Validate required parameters
  if (!timeEntryId || lat === undefined || lng === undefined) {
    logger.warn("clockOut: Missing required parameters", {uid, timeEntryId});
    throw new functions.HttpsError("invalid-argument", "Missing required parameters: timeEntryId, lat, lng");
  }

  // Validate GPS accuracy
  // STAGING: Relaxed GPS threshold for indoor/testing scenarios (PRODUCTION should use 50m)
  if (accuracy && accuracy > 200) {
    throw new functions.HttpsError(
      "failed-precondition",
      "GPS accuracy too low. Please wait for better signal (current: " + accuracy.toFixed(0) + "m)"
    );
  }

  // Validate coordinates and accuracy
  if (lat < -90 || lat > 90) {
    throw new functions.HttpsError("invalid-argument", "Invalid latitude: must be between -90 and 90");
  }
  if (lng < -180 || lng > 180) {
    throw new functions.HttpsError("invalid-argument", "Invalid longitude: must be between -180 and 180");
  }
  if (accuracy && (accuracy < 0 || accuracy > 2000 || isNaN(accuracy))) {
    throw new functions.HttpsError("invalid-argument", "Invalid accuracy: must be between 0 and 2000 meters");
  }

  const db = admin.firestore();

  // Idempotency check via clientEventId (if provided)
  if (clientEventId) {
    // Validate clientEventId TTL (prevent replay attacks)
    validateEventIdTTL(clientEventId, 'clockOut');

    const existingClockOutQuery = await db.collection("time_entries")
      .where("userId", "==", uid)
      .where("clockOutClientEventId", "==", clientEventId)
      .limit(1)
      .get();

    if (!existingClockOutQuery.empty) {
      logger.info("clockOut: Idempotent replay detected", {
        uid,
        timeEntryId,
        clientEventId,
        deviceId: deviceId ?? "unknown",
      });
      return {ok: true};
    }
  }

  // TRANSACTIONAL: Verify entry is active and update atomically
  const result = await db.runTransaction(async (tx) => {
    const entryRef = db.doc(`time_entries/${timeEntryId}`);
    const entrySnap = await tx.get(entryRef);

    if (!entrySnap.exists) {
      throw new functions.HttpsError("not-found", "Time entry not found");
    }

    const entry = entrySnap.data()!;

    // Verify ownership
    if (entry.userId !== uid) {
      throw new functions.HttpsError("permission-denied", "Not your time entry");
    }

    // Idempotent: if already clocked out, return success
    if (entry.clockOutAt !== null) {
      logger.info("clockOut: Already clocked out", {
        uid,
        timeEntryId,
        companyId: entry.companyId,
        jobId: entry.jobId,
        clientEventId: clientEventId ?? "missing",
      });
      return {
        ok: true,
        alreadyClocked: true,
      };
    }

    // Fetch job for geofence validation and normalize to canonical schema
    const jobSnap = await tx.get(db.doc(`jobs/${entry.jobId}`));
    if (!jobSnap.exists) {
      throw new functions.HttpsError("not-found", "Job not found");
    }

    // Normalize job to handle both legacy and canonical formats
    const job = normalizeJob(jobSnap.data() as any);

    // Distance check - record result but allow clock-out (flag for review)
    // CRITICAL: Use nested geofence structure (canonical v2.0 schema)
    const distance = HAVERSINE(
      {lat: job.geofence.lat, lng: job.geofence.lng},
      {lat, lng}
    );

    const baseRadius = Math.max(75, Math.min(job.geofence.radiusM ?? 100, 250));
    const accuracyBuffer = Math.max(accuracy ?? 0, 15);
    const effectiveRadius = baseRadius + accuracyBuffer;

    const clockOutGeofenceValid = distance <= effectiveRadius;
    const needsReview = !clockOutGeofenceValid;

    logger.info("clockOut: Geofence check", {
      uid,
      timeEntryId,
      jobId: entry.jobId,
      companyId: entry.companyId,
      distanceM: Math.round(distance * 10) / 10,
      radiusM: baseRadius,
      accuracyM: accuracy ?? null,
      effectiveRadiusM: Math.round(effectiveRadius * 10) / 10,
      decision: clockOutGeofenceValid ? "ALLOW" : "ALLOW_WITH_WARNING",
      flagged: needsReview,
      clientEventId: clientEventId ?? "missing",
      deviceId: deviceId ?? "unknown",
    });

    // Update time entry with clock out time, location, and geofence status (canonical v2.0 schema)
    const updates: Record<string, any> = {
      status: "completed", // Mark as completed
      clockOutAt: admin.firestore.FieldValue.serverTimestamp(),
      clockOutLoc: new admin.firestore.GeoPoint(lat, lng), // Fixed: clockOutLoc not clockOutLocation
      clockOutGeofenceValid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      // Audit fields (non-canonical but useful for debugging)
      distanceAtOutM: distance,
      accuracyAtOutM: accuracy ?? null,
    };

    // Store clientEventId for idempotency (if provided)
    if (clientEventId) {
      updates.clockOutClientEventId = clientEventId;
    }

    // Add exception tags for Admin Review
    if (needsReview) {
      updates.exceptionTags = admin.firestore.FieldValue.arrayUnion("geofence_out");
      logger.info("clockOut: Exception tagged", {
        uid,
        timeEntryId,
        companyId: entry.companyId,
        tag: "geofence_out",
        distanceM: Math.round(distance * 10) / 10,
      });
    }

    tx.update(entryRef, updates);

    return {
      ok: true,
      clockOutGeofenceValid,
      distance,
      alreadyClocked: false,
      companyId: entry.companyId,
      jobId: entry.jobId,
    };
  });

  // Return warning if outside geofence
  if (result.alreadyClocked) {
    return {ok: true}; // Idempotent response
  }

  logger.info("clockOut: Success", {
    uid,
    timeEntryId,
    companyId: result.companyId,
    jobId: result.jobId,
    clockOutGeofenceValid: result.clockOutGeofenceValid,
    distanceM: result.distance !== undefined ? Math.round(result.distance * 10) / 10 : null,
    flagged: !result.clockOutGeofenceValid,
    clientEventId: clientEventId ?? "missing",
    deviceId: deviceId ?? "unknown",
  });

  if (!result.clockOutGeofenceValid && result.distance !== undefined) {
    return {
      ok: true,
      warning: `Clocked out outside geofence (${result.distance.toFixed(1)}m from job site). Entry flagged for review.`,
    };
  }

  return {ok: true};
});
