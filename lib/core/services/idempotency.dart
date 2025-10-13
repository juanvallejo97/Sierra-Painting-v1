/// Idempotency Service
///
/// PURPOSE:
/// Generates unique event IDs for idempotent operations with embedded timestamps.
/// Ensures repeated network calls (e.g., double-tap, retry) are deduplicated server-side.
/// Prevents replay attacks by enforcing 24-hour TTL.
///
/// USAGE:
/// ```dart
/// final eventId = Idempotency.newEventId();
/// await api.clockIn(jobId: job.id, clientEventId: eventId, ...);
/// ```
///
/// IMPLEMENTATION:
/// Format: {timestamp}-{uuid}
/// - Timestamp: milliseconds since epoch (for TTL validation)
/// - UUID: v4 random UUID (for uniqueness)
/// Example: "1697000000000-550e8400-e29b-41d4-a716-446655440000"
///
/// SECURITY:
/// Server enforces 24-hour TTL on event IDs to prevent replay attacks.
library;

import 'package:uuid/uuid.dart';

/// Idempotency helper
class Idempotency {
  static const _uuid = Uuid();

  /// Generate new unique event ID with embedded timestamp
  ///
  /// Format: {timestamp}-{uuid}
  /// Returns string like "1697000000000-550e8400-e29b-41d4-a716-446655440000"
  ///
  /// The timestamp prefix enables server-side TTL validation (24-hour expiry)
  /// to prevent replay attacks.
  static String newEventId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uuid = _uuid.v4();
    return '$timestamp-$uuid';
  }
}
