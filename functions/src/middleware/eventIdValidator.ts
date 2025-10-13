/**
 * Client Event ID Validator
 *
 * Prevents replay attacks by enforcing TTL on clientEventId values.
 * Requires clientEventId to follow format: {timestamp}-{uuid} or UUIDv7
 *
 * SECURITY:
 * - Prevents replay attacks (attacker cannot reuse old event IDs)
 * - 24-hour TTL: Event IDs older than 24 hours are rejected
 * - Format validation: Ensures timestamp is embedded in event ID
 *
 * USAGE:
 * ```typescript
 * import { validateEventIdTTL } from './middleware/eventIdValidator';
 *
 * // Validate event ID is fresh (< 24 hours old)
 * validateEventIdTTL(clientEventId, 'clockIn');
 * ```
 */

import { HttpsError } from 'firebase-functions/v2/https';

/**
 * TTL for clientEventId (24 hours in milliseconds)
 */
const EVENT_ID_TTL_MS = 24 * 60 * 60 * 1000;

/**
 * Validate clientEventId TTL
 *
 * Checks if the event ID is fresh (created within last 24 hours).
 * Supports two formats:
 * 1. Timestamp prefix: {timestamp}-{uuid} (e.g., "1697000000000-abc123")
 * 2. UUIDv7: First 48 bits are Unix timestamp in milliseconds
 *
 * @param clientEventId - Client event identifier
 * @param operation - Operation name (for error messages)
 * @throws HttpsError if event ID is expired or invalid format
 */
export function validateEventIdTTL(
  clientEventId: string,
  operation: string
): void {
  // Try timestamp prefix format first: {timestamp}-{uuid}
  const timestampMatch = clientEventId.match(/^(\d{13})-/);
  if (timestampMatch) {
    const timestamp = parseInt(timestampMatch[1], 10);
    const age = Date.now() - timestamp;

    if (age >= EVENT_ID_TTL_MS) {
      throw new HttpsError(
        'invalid-argument',
        `Event ID expired. ${operation} must use event ID created within last 24 hours. ` +
        `Current age: ${Math.floor(age / 1000 / 60 / 60)} hours.`
      );
    }

    if (age < 0) {
      throw new HttpsError(
        'invalid-argument',
        `Event ID timestamp is in the future. Clock skew detected.`
      );
    }

    return;
  }

  // Try UUIDv7 format (timestamp embedded in first 48 bits)
  if (clientEventId.length === 36 && clientEventId[8] === '-' && clientEventId[13] === '-') {
    try {
      const timestamp = extractUUIDv7Timestamp(clientEventId);
      if (timestamp) {
        const age = Date.now() - timestamp;

        if (age >= EVENT_ID_TTL_MS) {
          throw new HttpsError(
            'invalid-argument',
            `Event ID expired (UUIDv7). ${operation} must use event ID created within last 24 hours.`
          );
        }

        if (age < 0) {
          throw new HttpsError(
            'invalid-argument',
            `Event ID timestamp is in the future (UUIDv7). Clock skew detected.`
          );
        }

        return;
      }
    } catch {
      // Not a valid UUIDv7, fall through to error
    }
  }

  // Event ID doesn't include timestamp - reject for security
  throw new HttpsError(
    'invalid-argument',
    `Invalid event ID format. Must include timestamp: either ` +
    `"{timestamp}-{uuid}" format (e.g., "${Date.now()}-abc123") or UUIDv7.`
  );
}

/**
 * Extract timestamp from UUIDv7
 *
 * UUIDv7 format (RFC draft):
 * - First 48 bits: Unix timestamp in milliseconds
 * - Remaining bits: random
 *
 * Format: xxxxxxxx-xxxx-7xxx-yxxx-xxxxxxxxxxxx
 * where first 12 hex chars (48 bits) are timestamp
 *
 * @param uuid - UUIDv7 string
 * @returns Timestamp in milliseconds, or null if not UUIDv7
 */
function extractUUIDv7Timestamp(uuid: string): number | null {
  // Check version is 7 (position 14, should be '7')
  if (uuid[14] !== '7') {
    return null;
  }

  try {
    // Extract first 48 bits (12 hex characters)
    const timestampHex = uuid.substring(0, 8) + uuid.substring(9, 13);
    const timestamp = parseInt(timestampHex, 16);

    // Sanity check: timestamp should be reasonable (after 2020, before 2100)
    const year2020 = 1577836800000;
    const year2100 = 4102444800000;
    if (timestamp < year2020 || timestamp > year2100) {
      return null;
    }

    return timestamp;
  } catch {
    return null;
  }
}

/**
 * Generate a valid clientEventId with current timestamp
 *
 * This is a helper for client SDKs to generate compliant event IDs.
 * Can be used in tests or documentation.
 *
 * @returns Event ID in format: {timestamp}-{uuid}
 */
export function generateClientEventId(): string {
  const timestamp = Date.now();
  const random = Math.random().toString(36).substring(2, 15);
  return `${timestamp}-${random}`;
}
