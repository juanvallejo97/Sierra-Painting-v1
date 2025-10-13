/// Pending Clock Operation Model (K1)
///
/// Represents a clock in/out operation queued for later sync when offline.
/// Stored in Hive and replayed automatically when connectivity is restored.
library;

import 'package:hive/hive.dart';

part 'pending_entry.g.dart';

/// Pending clock operation (K1 - Offline Queue)
///
/// Queued when the user performs a clock in/out action while offline.
/// Contains all necessary data to replay the operation when back online.
@HiveType(typeId: 1)
class PendingClockOp {
  /// Operation type: 'clockIn' or 'clockOut'
  @HiveField(0)
  final String op;

  /// Job ID (required for clockIn, optional for clockOut)
  @HiveField(1)
  final String? jobId;

  /// Latitude at time of clock action
  @HiveField(2)
  final double lat;

  /// Longitude at time of clock action
  @HiveField(3)
  final double lng;

  /// GPS accuracy in meters (for geofence buffer calculation)
  @HiveField(4)
  final double? accuracy;

  /// Client-side event ID for idempotency (prevents duplicates)
  @HiveField(5)
  final String clientEventId;

  /// When this operation was queued locally
  @HiveField(6)
  final DateTime createdAt;

  /// User ID performing the action
  @HiveField(7)
  final String userId;

  /// Number of sync attempts made
  @HiveField(8)
  final int retryCount;

  /// Last sync attempt timestamp (for exponential backoff)
  @HiveField(9)
  final DateTime? lastAttemptAt;

  /// Error from last sync attempt (for debugging)
  @HiveField(10)
  final String? lastError;

  PendingClockOp({
    required this.op,
    this.jobId,
    required this.lat,
    required this.lng,
    this.accuracy,
    required this.clientEventId,
    required this.createdAt,
    required this.userId,
    this.retryCount = 0,
    this.lastAttemptAt,
    this.lastError,
  });

  /// Create clock-in operation
  factory PendingClockOp.clockIn({
    required String jobId,
    required double lat,
    required double lng,
    double? accuracy,
    required String clientEventId,
    required String userId,
  }) {
    return PendingClockOp(
      op: 'clockIn',
      jobId: jobId,
      lat: lat,
      lng: lng,
      accuracy: accuracy,
      clientEventId: clientEventId,
      createdAt: DateTime.now(),
      userId: userId,
    );
  }

  /// Create clock-out operation
  factory PendingClockOp.clockOut({
    required double lat,
    required double lng,
    double? accuracy,
    required String clientEventId,
    required String userId,
  }) {
    return PendingClockOp(
      op: 'clockOut',
      lat: lat,
      lng: lng,
      accuracy: accuracy,
      clientEventId: clientEventId,
      createdAt: DateTime.now(),
      userId: userId,
    );
  }

  /// Copy with updated retry information
  PendingClockOp copyWith({
    int? retryCount,
    DateTime? lastAttemptAt,
    String? lastError,
  }) {
    return PendingClockOp(
      op: op,
      jobId: jobId,
      lat: lat,
      lng: lng,
      accuracy: accuracy,
      clientEventId: clientEventId,
      createdAt: createdAt,
      userId: userId,
      retryCount: retryCount ?? this.retryCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastError: lastError ?? this.lastError,
    );
  }

  /// Check if this is a clock-in operation
  bool get isClockIn => op == 'clockIn';

  /// Check if this is a clock-out operation
  bool get isClockOut => op == 'clockOut';

  /// Calculate exponential backoff delay in seconds
  /// Retry schedule: 5s, 15s, 45s, 135s (2m15s), 300s (5m max)
  int get backoffDelay {
    if (retryCount == 0) return 0;
    final delay = 5 * (1 << (retryCount - 1)); // 5 * 2^(n-1)
    return delay > 300 ? 300 : delay; // Cap at 5 minutes
  }

  /// Check if enough time has passed for next retry
  bool get canRetry {
    if (lastAttemptAt == null) return true;
    final elapsed = DateTime.now().difference(lastAttemptAt!);
    return elapsed.inSeconds >= backoffDelay;
  }

  /// Human-readable description for UI
  String get description {
    if (isClockIn) {
      return 'Clock In to job $jobId';
    } else {
      return 'Clock Out';
    }
  }

  @override
  String toString() {
    return 'PendingClockOp(op: $op, jobId: $jobId, clientEventId: $clientEventId, '
        'createdAt: $createdAt, retryCount: $retryCount)';
  }
}
