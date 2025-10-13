/// Idempotency Service
///
/// PURPOSE:
/// Generates unique event IDs for idempotent operations.
/// Ensures repeated network calls (e.g., double-tap, retry) are deduplicated server-side.
///
/// USAGE:
/// ```dart
/// final eventId = Idempotency.newEventId();
/// await api.clockIn(jobId: job.id, clientEventId: eventId, ...);
/// ```
///
/// IMPLEMENTATION:
/// Uses UUID v4 for globally unique, collision-resistant IDs.
library;

import 'package:uuid/uuid.dart';

/// Idempotency helper
class Idempotency {
  static const _uuid = Uuid();

  /// Generate new unique event ID
  ///
  /// Returns UUID v4 string (e.g., "550e8400-e29b-41d4-a716-446655440000")
  static String newEventId() => _uuid.v4();
}
