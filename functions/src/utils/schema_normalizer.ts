/**
 * Schema Normalizer
 *
 * PURPOSE:
 * Ensures canonical field names are used in Firestore writes.
 * Strips legacy/alias fields to prevent schema drift.
 *
 * CANONICAL SCHEMA (timeEntries):
 * - clockInAt/clockOutAt (not clockIn/clockOut or at)
 * - clockInLoc/clockOutLoc (GeoPoint, not lat/lng/geo)
 * - geoOkIn/geoOkOut (boolean)
 * - exceptionTags (string[])
 * - approved, approvedAt, approvedBy
 * - invoiceId (if invoiced)
 * - deviceId, clientEventId
 * - radiusUsedM, accuracyAtInM, distanceAtInM
 *
 * USAGE:
 * import { normalizeTimeEntry } from './utils/schema_normalizer';
 *
 * const normalized = normalizeTimeEntry(rawData);
 * await timeEntryRef.set(normalized);
 */

import * as admin from 'firebase-admin';

/**
 * Legacy field aliases to strip
 */
const LEGACY_FIELDS = [
  'clockIn',      // Use clockInAt
  'clockOut',     // Use clockOutAt
  'at',           // Use clockInAt/clockOutAt
  'geo',          // Use clockInLoc/clockOutLoc
  'lat',          // Use clockInLoc.latitude
  'lng',          // Use clockInLoc.longitude
  'geoOk',        // Use geoOkIn/geoOkOut
  'exception',    // Use exceptionTags array
  'approved_by',  // Use approvedBy (camelCase)
  'approved_at',  // Use approvedAt (camelCase)
  'invoice_id',   // Use invoiceId (camelCase)
];

/**
 * Normalize time entry data to canonical schema
 *
 * @param data - Raw time entry data (may contain legacy fields)
 * @returns Normalized data with only canonical fields
 */
export function normalizeTimeEntry(data: any): any {
  const normalized: any = {};

  // Copy all non-legacy fields
  for (const [key, value] of Object.entries(data)) {
    if (!LEGACY_FIELDS.includes(key)) {
      normalized[key] = value;
    }
  }

  // Ensure required fields are present with correct types
  if (!normalized.exceptionTags || !Array.isArray(normalized.exceptionTags)) {
    normalized.exceptionTags = [];
  }

  // Ensure boolean flags are boolean (not null/undefined)
  if (normalized.approved === null || normalized.approved === undefined) {
    normalized.approved = false;
  }

  // Ensure geoOkIn/geoOkOut are boolean when present
  if (normalized.geoOkIn !== null && normalized.geoOkIn !== undefined) {
    normalized.geoOkIn = Boolean(normalized.geoOkIn);
  }
  if (normalized.geoOkOut !== null && normalized.geoOkOut !== undefined) {
    normalized.geoOkOut = Boolean(normalized.geoOkOut);
  }

  return normalized;
}

/**
 * Ensure time entry is mutable (not approved or invoiced)
 *
 * Throws HttpsError if entry is immutable.
 * Call this before any mutation (except approval/linking).
 *
 * @param entry - Time entry data
 * @throws HttpsError if entry is approved or invoiced
 */
export function ensureMutable(entry: any): void {
  const { HttpsError } = require('firebase-functions/v2/https');

  if (entry.approved === true) {
    throw new HttpsError(
      'failed-precondition',
      'Cannot modify approved time entry. Contact admin to unapprove first.'
    );
  }

  if (entry.invoiceId) {
    throw new HttpsError(
      'failed-precondition',
      `Cannot modify invoiced time entry (invoice: ${entry.invoiceId}). Contact admin.`
    );
  }
}

/**
 * Backfill script: Normalize all time entries in staging
 *
 * Run once after deployment to clean up any legacy fields.
 * Safe to run multiple times (idempotent).
 *
 * USAGE:
 * firebase functions:shell --project sierra-staging
 * > backfillNormalizeTimeEntries()
 */
export async function backfillNormalizeTimeEntries(): Promise<{
  processed: number;
  updated: number;
  errors: number;
}> {
  const db = admin.firestore();
  const batch = db.batch();

  let processed = 0;
  let updated = 0;
  let errors = 0;

  const snapshot = await db.collection('timeEntries').limit(500).get();

  for (const doc of snapshot.docs) {
    try {
      processed++;
      const data = doc.data();
      const normalized = normalizeTimeEntry(data);

      // Check if normalization changed anything
      const hasLegacyFields = LEGACY_FIELDS.some(field => field in data);

      if (hasLegacyFields) {
        batch.update(doc.ref, normalized);
        updated++;
      }
    } catch (error) {
      errors++;
      console.error(`Error normalizing entry ${doc.id}:`, error);
    }
  }

  if (updated > 0) {
    await batch.commit();
  }

  return { processed, updated, errors };
}
