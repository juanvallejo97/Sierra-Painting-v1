/**
 * Canonical TypeScript Type Definitions
 *
 * Version: 2.0 (Option B Stability Patch)
 * Last Updated: 2025-10-12
 *
 * IMPORTANT: These types are the single source of truth for Cloud Functions.
 * They match the canonical schemas in docs/schemas/
 *
 * DO NOT modify these types without updating the schema documentation first.
 */

import * as admin from 'firebase-admin';

// Type aliases for Firebase types
type Timestamp = admin.firestore.Timestamp;
type GeoPoint = admin.firestore.GeoPoint;

// Lightweight location type (avoids GeoPoint for better serialization)
export interface GeoPointLike {
  lat: number;
  lng: number;
}

// ============================================================================
// User Schema
// ============================================================================

/**
 * User document stored in Firestore: /users/{userId}
 *
 * IMPORTANT: Role and company membership are stored in Firebase Auth Custom Claims,
 * NOT in this Firestore document (for security reasons).
 *
 * See docs/schemas/user.md for full documentation.
 */
export interface User {
  userId: string;
  displayName: string;
  email: string;
  photoURL?: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

/**
 * Custom Claims (stored in Firebase Auth JWT token, not Firestore)
 *
 * Access via: req.auth.token.companyId, req.auth.token.role, etc.
 */
export interface UserClaims {
  companyId: string;
  role: 'worker' | 'admin' | 'manager';
  active: boolean;
}

// ============================================================================
// Job Schema
// ============================================================================

/**
 * Geofence nested object (part of Job document)
 *
 * CRITICAL: This is a NESTED object within Job, not top-level fields.
 */
export interface Geofence {
  lat: number;      // Latitude in degrees (-90 to 90)
  lng: number;      // Longitude in degrees (-180 to 180)
  radiusM: number;  // Radius in meters (75-250)
}

/**
 * Job document stored in Firestore: /jobs/{jobId}
 *
 * Represents a job site with geofence boundary for time tracking.
 *
 * See docs/schemas/job.md for full documentation.
 */
export interface Job {
  jobId: string;
  companyId: string;
  name: string;
  address: string;
  geofence: Geofence;  // ← NESTED OBJECT
  active: boolean;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

/**
 * Legacy Job structure (DEPRECATED - Remove after 2025-10-26)
 *
 * For migration compatibility only. Use Job interface for new code.
 */
export interface LegacyJob {
  jobId: string;
  companyId: string;
  name: string;
  address: string;
  lat?: number;             // DEPRECATED: Use geofence.lat
  lng?: number;             // DEPRECATED: Use geofence.lng
  radiusM?: number;         // DEPRECATED: Use geofence.radiusM
  radiusMeters?: number;    // DEPRECATED: Use geofence.radiusM
  latitude?: number;        // DEPRECATED: Use geofence.lat
  longitude?: number;       // DEPRECATED: Use geofence.lng
  geofence?: Geofence;      // New nested structure
  active: boolean;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

// ============================================================================
// Assignment Schema
// ============================================================================

/**
 * Assignment document stored in Firestore: /assignments/{assignmentId}
 *
 * Links a worker (user) to a job site. Determines which jobs a worker
 * is authorized to clock in to.
 *
 * See docs/schemas/assignment.md for full documentation.
 */
export interface Assignment {
  assignmentId: string;
  companyId: string;
  userId: string;
  jobId: string;
  active: boolean;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

// ============================================================================
// TimeEntry Schema
// ============================================================================

/**
 * TimeEntry document stored in Firestore: /time_entries/{entryId}
 *
 * Represents a single clock in/out record for a worker at a job site.
 *
 * See docs/schemas/time_entry.md for full documentation.
 */
export interface TimeEntry {
  entryId: string;
  companyId: string;
  userId: string;
  jobId: string;
  clockInAt: Timestamp;
  clockInGeofenceValid: boolean;
  clockInLocation?: GeoPointLike;
  clockOutAt?: Timestamp;
  clockOutGeofenceValid?: boolean;
  clockOutLocation?: GeoPointLike;
  notes?: string;
  createdAt?: Timestamp;
  updatedAt?: Timestamp;
}

/**
 * Legacy TimeEntry structure (DEPRECATED - Remove after 2025-10-26)
 *
 * For migration compatibility only. Use TimeEntry interface for new code.
 */
export interface LegacyTimeEntry {
  entryId: string;
  companyId: string;
  userId?: string;          // NEW
  workerId?: string;        // DEPRECATED: Use userId
  jobId: string;
  clockInAt?: Timestamp;    // NEW
  clockIn?: Timestamp;      // DEPRECATED: Use clockInAt
  clockInLocation?: GeoPoint;
  clockInGeofenceValid?: boolean;
  clockOutAt?: Timestamp;   // NEW
  clockOut?: Timestamp;     // DEPRECATED: Use clockOutAt
  clockOutLocation?: GeoPoint;
  clockOutGeofenceValid?: boolean;
  location?: GeoPoint;      // DEPRECATED: Split into clockInLocation/clockOutLocation
  geofenceValid?: boolean;  // DEPRECATED: Split into clockInGeofenceValid/clockOutGeofenceValid
  notes?: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

// ============================================================================
// Utility Types
// ============================================================================

/**
 * Standard API response wrapper for callable functions
 */
export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  error?: string;
  code?: string;
}

/**
 * Location data passed from client
 */
export interface LocationData {
  lat: number;
  lng: number;
  accuracy: number;
}

/**
 * Clock In request payload
 */
export interface ClockInRequest {
  jobId: string;
  lat: number;
  lng: number;
  accuracy: number;
  clientEventId: string;  // For idempotency
}

/**
 * Clock Out request payload
 */
export interface ClockOutRequest {
  entryId: string;
  lat: number;
  lng: number;
  accuracy: number;
  notes?: string;
  clientEventId: string;  // For idempotency
}

/**
 * Geofence validation result
 */
export interface GeofenceValidation {
  isValid: boolean;
  distance: number;
  effectiveRadius: number;
  accuracy: number;
}

// ============================================================================
// Type Guards
// ============================================================================

/**
 * Type guard to check if job has new nested geofence structure
 */
export function hasNestedGeofence(job: Job | LegacyJob): job is Job {
  return job.geofence !== undefined &&
         typeof job.geofence === 'object' &&
         'lat' in job.geofence &&
         'lng' in job.geofence &&
         'radiusM' in job.geofence;
}

/**
 * Type guard to check if time entry uses new field names
 */
export function isCanonicalTimeEntry(entry: TimeEntry | LegacyTimeEntry): entry is TimeEntry {
  return 'userId' in entry && 'clockInAt' in entry;
}

// ============================================================================
// Migration Helpers
// ============================================================================

/**
 * Normalize job to canonical structure (handles legacy formats)
 *
 * @param job - Job document from Firestore (may be legacy format)
 * @returns Normalized job with canonical geofence structure
 * @throws Error if geofence data is missing or invalid
 */
export function normalizeJob(job: Job | LegacyJob): Job {
  // If already has nested geofence, return as-is
  if (hasNestedGeofence(job)) {
    return job;
  }

  // Fallback to legacy flat fields
  const legacyJob = job as LegacyJob;
  const lat = legacyJob.geofence?.lat ?? legacyJob.lat ?? legacyJob.latitude;
  const lng = legacyJob.geofence?.lng ?? legacyJob.lng ?? legacyJob.longitude;
  const radiusM = legacyJob.geofence?.radiusM ?? legacyJob.radiusM ?? legacyJob.radiusMeters;

  if (!lat || !lng || !radiusM) {
    throw new Error(
      `Job ${job.jobId} has invalid geofence. Expected nested geofence object or legacy lat/lng/radiusM fields.`
    );
  }

  // Convert to canonical structure
  return {
    jobId: job.jobId,
    companyId: job.companyId,
    name: job.name,
    address: job.address,
    geofence: { lat, lng, radiusM },
    active: job.active,
    createdAt: job.createdAt,
    updatedAt: job.updatedAt,
  };
}

/**
 * Convert GeoPoint to GeoPointLike (helper for normalization)
 */
function convertGeoPoint(geoPoint?: GeoPoint): GeoPointLike | undefined {
  if (!geoPoint) return undefined;
  return {
    lat: geoPoint.latitude,
    lng: geoPoint.longitude,
  };
}

/**
 * Normalize time entry to canonical structure (handles legacy formats)
 *
 * @param entry - TimeEntry document from Firestore (may be legacy format)
 * @returns Normalized time entry with canonical field names
 * @throws Error if required fields are missing
 */
export function normalizeTimeEntry(entry: TimeEntry | LegacyTimeEntry): TimeEntry {
  // If already canonical, return as-is
  if (isCanonicalTimeEntry(entry)) {
    return entry;
  }

  // Fallback to legacy field names
  const legacyEntry = entry as LegacyTimeEntry;
  const userId = legacyEntry.userId ?? legacyEntry.workerId;
  const clockInAt = legacyEntry.clockInAt ?? legacyEntry.clockIn;
  const clockOutAt = legacyEntry.clockOutAt ?? legacyEntry.clockOut;

  if (!userId || !clockInAt) {
    throw new Error(
      `TimeEntry ${entry.entryId} missing required fields (userId/clockInAt)`
    );
  }

  // Convert GeoPoint to GeoPointLike for locations
  const clockInLocation = convertGeoPoint(legacyEntry.clockInLocation ?? legacyEntry.location);
  const clockOutLocation = convertGeoPoint(legacyEntry.clockOutLocation);

  // Convert to canonical structure
  return {
    entryId: entry.entryId,
    companyId: entry.companyId,
    userId,
    jobId: entry.jobId,
    clockInAt,
    clockInLocation,
    clockInGeofenceValid: legacyEntry.clockInGeofenceValid ?? legacyEntry.geofenceValid ?? false,
    clockOutAt,
    clockOutLocation,
    clockOutGeofenceValid: legacyEntry.clockOutGeofenceValid,
    notes: entry.notes,
    createdAt: entry.createdAt,
    updatedAt: entry.updatedAt,
  };
}

// ============================================================================
// Exports
// ============================================================================

export default {
  normalizeJob,
  normalizeTimeEntry,
  hasNestedGeofence,
  isCanonicalTimeEntry,
};
