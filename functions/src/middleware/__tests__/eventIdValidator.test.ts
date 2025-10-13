/**
 * Tests for clientEventId TTL validator
 */

import {validateEventIdTTL, generateClientEventId} from '../eventIdValidator';
import {HttpsError} from 'firebase-functions/v2/https';

describe('clientEventId TTL Validation', () => {
  describe('Timestamp-prefixed format ({timestamp}-{uuid})', () => {
    it('should accept fresh event ID (< 24 hours old)', () => {
      const now = Date.now();
      const clientEventId = `${now}-abc123-def456`;

      expect(() => validateEventIdTTL(clientEventId, 'clockIn')).not.toThrow();
    });

    it('should accept event ID created 23 hours ago', () => {
      const twentyThreeHoursAgo = Date.now() - (23 * 60 * 60 * 1000);
      const clientEventId = `${twentyThreeHoursAgo}-abc123-def456`;

      expect(() => validateEventIdTTL(clientEventId, 'clockIn')).not.toThrow();
    });

    it('should reject event ID older than 24 hours', () => {
      const twentyFiveHoursAgo = Date.now() - (25 * 60 * 60 * 1000);
      const clientEventId = `${twentyFiveHoursAgo}-abc123-def456`;

      expect(() => validateEventIdTTL(clientEventId, 'clockIn')).toThrow(HttpsError);
      expect(() => validateEventIdTTL(clientEventId, 'clockIn')).toThrow('Event ID expired');
    });

    it('should reject event ID from future (clock skew)', () => {
      const oneHourInFuture = Date.now() + (60 * 60 * 1000);
      const clientEventId = `${oneHourInFuture}-abc123-def456`;

      expect(() => validateEventIdTTL(clientEventId, 'clockIn')).toThrow(HttpsError);
      expect(() => validateEventIdTTL(clientEventId, 'clockIn')).toThrow('timestamp is in the future');
    });

    it('should include operation name in error message', () => {
      const expired = Date.now() - (25 * 60 * 60 * 1000);
      const clientEventId = `${expired}-abc123`;

      expect(() => validateEventIdTTL(clientEventId, 'clockOut')).toThrow('clockOut');
    });

    it('should include age in hours in error message', () => {
      const twentyFiveHoursAgo = Date.now() - (25 * 60 * 60 * 1000);
      const clientEventId = `${twentyFiveHoursAgo}-abc123`;

      expect(() => validateEventIdTTL(clientEventId, 'clockIn')).toThrow('25 hours');
    });

    it('should handle various UUID formats after timestamp', () => {
      const now = Date.now();
      const formats = [
        `${now}-550e8400-e29b-41d4-a716-446655440000`, // UUIDv4 format
        `${now}-abc123`, // Short random
        `${now}-abc123def456ghi789`, // Long random
        `${now}-a1b2c3d4e5f6`, // Hex random
      ];

      formats.forEach(eventId => {
        expect(() => validateEventIdTTL(eventId, 'clockIn')).not.toThrow();
      });
    });
  });

  describe('UUIDv7 format (timestamp embedded)', () => {
    // Note: UUIDv7 support is implemented but not actively used.
    // The app uses timestamp-prefix format instead.
    // These tests verify rejection of invalid UUID formats.

    it('should reject UUID with wrong version (not v7)', () => {
      // Plain UUIDv4 should be rejected
      expect(() => validateEventIdTTL('550e8400-e29b-41d4-a716-446655440000', 'clockIn'))
        .toThrow('Invalid event ID format');
    });

    it('should reject malformed UUID format', () => {
      expect(() => validateEventIdTTL('not-a-uuid', 'clockIn')).toThrow('Invalid event ID format');
      expect(() => validateEventIdTTL('12345678-1234-5678-9abc', 'clockIn')).toThrow('Invalid event ID format');
      expect(() => validateEventIdTTL('', 'clockIn')).toThrow('Invalid event ID format');
    });
  });

  describe('Invalid formats', () => {
    it('should reject plain UUID (no timestamp)', () => {
      const uuidv4 = '550e8400-e29b-41d4-a716-446655440000';
      expect(() => validateEventIdTTL(uuidv4, 'clockIn')).toThrow('Invalid event ID format');
    });

    it('should reject random string', () => {
      expect(() => validateEventIdTTL('random-string-123', 'clockIn')).toThrow('Invalid event ID format');
    });

    it('should reject numeric-only ID', () => {
      expect(() => validateEventIdTTL('123456789', 'clockIn')).toThrow('Invalid event ID format');
    });

    it('should reject empty string', () => {
      expect(() => validateEventIdTTL('', 'clockIn')).toThrow('Invalid event ID format');
    });

    it('should reject ID with non-numeric timestamp prefix', () => {
      expect(() => validateEventIdTTL('abc1234567890-uuid', 'clockIn')).toThrow('Invalid event ID format');
    });

    it('should reject ID with too-short timestamp (< 13 digits)', () => {
      expect(() => validateEventIdTTL('123456789012-uuid', 'clockIn')).toThrow('Invalid event ID format');
    });
  });

  describe('generateClientEventId helper', () => {
    it('should generate valid event ID with timestamp prefix', () => {
      const eventId = generateClientEventId();
      expect(eventId).toMatch(/^\d{13}-.+/);
    });

    it('should generate unique IDs', () => {
      const id1 = generateClientEventId();
      const id2 = generateClientEventId();
      expect(id1).not.toBe(id2);
    });

    it('generated ID should pass validation', () => {
      const eventId = generateClientEventId();
      expect(() => validateEventIdTTL(eventId, 'clockIn')).not.toThrow();
    });

    it('should generate IDs with current timestamp', () => {
      const before = Date.now();
      const eventId = generateClientEventId();
      const after = Date.now();

      const timestampMatch = eventId.match(/^(\d{13})-/);
      expect(timestampMatch).not.toBeNull();

      const timestamp = parseInt(timestampMatch![1], 10);
      expect(timestamp).toBeGreaterThanOrEqual(before);
      expect(timestamp).toBeLessThanOrEqual(after);
    });
  });

  describe('Edge cases', () => {
    it('should handle event ID exactly at 24-hour boundary', () => {
      const exactlyTwentyFourHoursAgo = Date.now() - (24 * 60 * 60 * 1000);
      const clientEventId = `${exactlyTwentyFourHoursAgo}-abc123`;

      // Should reject (age >= 24 hours)
      expect(() => validateEventIdTTL(clientEventId, 'clockIn')).toThrow(HttpsError);
    });

    it('should handle event ID 1ms before 24-hour expiry', () => {
      const almostExpired = Date.now() - (24 * 60 * 60 * 1000 - 1);
      const clientEventId = `${almostExpired}-abc123`;

      // Should pass (age < 24 hours)
      expect(() => validateEventIdTTL(clientEventId, 'clockIn')).not.toThrow();
    });

    it('should handle very large timestamp (far future)', () => {
      const farFuture = Date.now() + (365 * 24 * 60 * 60 * 1000); // 1 year
      const clientEventId = `${farFuture}-abc123`;

      expect(() => validateEventIdTTL(clientEventId, 'clockIn')).toThrow('timestamp is in the future');
    });

    it('should handle very old timestamp (years ago)', () => {
      const yearsAgo = Date.now() - (365 * 24 * 60 * 60 * 1000); // 1 year
      const clientEventId = `${yearsAgo}-abc123`;

      expect(() => validateEventIdTTL(clientEventId, 'clockIn')).toThrow('Event ID expired');
    });

    it('should handle timestamp at Unix epoch start (1970)', () => {
      const clientEventId = '0000000000000-abc123'; // Jan 1, 1970
      expect(() => validateEventIdTTL(clientEventId, 'clockIn')).toThrow('Event ID expired');
    });
  });

  describe('Security scenarios', () => {
    it('prevents replay attack with captured 2-day-old event ID', () => {
      // Attacker captures event ID from network 2 days ago
      const twoDaysAgo = Date.now() - (2 * 24 * 60 * 60 * 1000);
      const capturedEventId = `${twoDaysAgo}-abc123-captured`;

      // Attacker tries to replay it
      expect(() => validateEventIdTTL(capturedEventId, 'clockIn')).toThrow(HttpsError);
      expect(() => validateEventIdTTL(capturedEventId, 'clockIn')).toThrow('Event ID expired');
    });

    it('allows legitimate offline operation (synced within 24h)', () => {
      // Worker clocks in offline, syncs 12 hours later
      const twelveHoursAgo = Date.now() - (12 * 60 * 60 * 1000);
      const offlineEventId = `${twelveHoursAgo}-offline-sync`;

      expect(() => validateEventIdTTL(offlineEventId, 'clockIn')).not.toThrow();
    });

    it('rejects offline operation synced after 24h', () => {
      // Worker clocks in offline, tries to sync 25 hours later (too old)
      const twentyFiveHoursAgo = Date.now() - (25 * 60 * 60 * 1000);
      const staleOfflineId = `${twentyFiveHoursAgo}-stale-offline`;

      expect(() => validateEventIdTTL(staleOfflineId, 'clockIn')).toThrow('Event ID expired');
    });
  });
});
