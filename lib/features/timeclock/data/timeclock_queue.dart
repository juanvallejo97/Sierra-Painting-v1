/// Timeclock Queue Service
///
/// PURPOSE:
/// Offline-first queue for time clock operations.
/// Ensures clock in/out events are never lost even when offline.
///
/// FEATURES:
/// - Queue clock-in/out operations when offline
/// - Automatic retry with exponential backoff
/// - Idempotency using clientEventId
/// - Sync status tracking
/// - Conflict resolution
///
/// PRODUCTION REQUIREMENTS (per coach notes):
/// - Fail-soft offline with queue sync
/// - Idempotency tokens prevent duplicates
/// - Multi-device double-punch prevention
/// - Graceful degradation when network unavailable
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/services/location_service.dart';

/// Operation type in queue
enum QueueOperationType {
  /// Clock in operation
  clockIn,

  /// Clock out operation
  clockOut,

  /// Start break
  startBreak,

  /// End break
  endBreak,

  /// Dispute time entry
  dispute;

  String toFirestore() => name;
}

/// Queue operation status
enum QueueOperationStatus {
  /// Pending - not yet attempted
  pending,

  /// In progress - currently syncing
  syncing,

  /// Failed - will retry
  failed,

  /// Completed - successfully synced
  completed,

  /// Cancelled - user cancelled operation
  cancelled;

  bool get isPending => this == QueueOperationStatus.pending;
  bool get isSyncing => this == QueueOperationStatus.syncing;
  bool get isFailed => this == QueueOperationStatus.failed;
  bool get isCompleted => this == QueueOperationStatus.completed;
  bool get shouldRetry => this == QueueOperationStatus.failed;

  String toFirestore() => name;
}

/// Queued timeclock operation
class QueuedOperation {
  final String id; // Local queue ID
  final QueueOperationType type;
  final QueueOperationStatus status;

  // Operation data
  final String clientEventId; // For idempotency
  final String workerId;
  final String jobId;
  final DateTime timestamp;
  final LocationResult? location;

  // Additional data (type-specific)
  final String? notes;
  final String? disputeReason;
  final String? breakType; // 'paid' or 'unpaid'

  // Retry tracking
  final int retryCount;
  final DateTime? lastAttempt;
  final String? lastError;
  final DateTime? nextRetry;

  // Metadata
  final DateTime createdAt;
  final DateTime? completedAt;

  QueuedOperation({
    required this.id,
    required this.type,
    required this.status,
    required this.clientEventId,
    required this.workerId,
    required this.jobId,
    required this.timestamp,
    this.location,
    this.notes,
    this.disputeReason,
    this.breakType,
    this.retryCount = 0,
    this.lastAttempt,
    this.lastError,
    this.nextRetry,
    required this.createdAt,
    this.completedAt,
  });

  /// Create copy with updated fields
  QueuedOperation copyWith({
    String? id,
    QueueOperationType? type,
    QueueOperationStatus? status,
    String? clientEventId,
    String? workerId,
    String? jobId,
    DateTime? timestamp,
    LocationResult? location,
    String? notes,
    String? disputeReason,
    String? breakType,
    int? retryCount,
    DateTime? lastAttempt,
    String? lastError,
    DateTime? nextRetry,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return QueuedOperation(
      id: id ?? this.id,
      type: type ?? this.type,
      status: status ?? this.status,
      clientEventId: clientEventId ?? this.clientEventId,
      workerId: workerId ?? this.workerId,
      jobId: jobId ?? this.jobId,
      timestamp: timestamp ?? this.timestamp,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      disputeReason: disputeReason ?? this.disputeReason,
      breakType: breakType ?? this.breakType,
      retryCount: retryCount ?? this.retryCount,
      lastAttempt: lastAttempt ?? this.lastAttempt,
      lastError: lastError ?? this.lastError,
      nextRetry: nextRetry ?? this.nextRetry,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// Check if operation is ready for retry
  bool get isReadyForRetry {
    if (!status.shouldRetry) return false;
    if (nextRetry == null) return true;
    return DateTime.now().isAfter(nextRetry!);
  }

  /// Calculate next retry time with exponential backoff
  /// Retry delays: 10s, 30s, 1m, 5m, 15m, 30m (max)
  DateTime calculateNextRetry() {
    final delays = [10, 30, 60, 300, 900, 1800]; // seconds
    final delayIndex = retryCount < delays.length
        ? retryCount
        : delays.length - 1;
    final delaySeconds = delays[delayIndex];
    return DateTime.now().add(Duration(seconds: delaySeconds));
  }

  /// User-friendly status message
  String get statusMessage {
    switch (status) {
      case QueueOperationStatus.pending:
        return 'Waiting to sync...';
      case QueueOperationStatus.syncing:
        return 'Syncing...';
      case QueueOperationStatus.failed:
        if (nextRetry != null) {
          final secondsUntil = nextRetry!.difference(DateTime.now()).inSeconds;
          return 'Retry in ${secondsUntil}s';
        }
        return 'Failed - will retry';
      case QueueOperationStatus.completed:
        return 'Synced';
      case QueueOperationStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Abstract timeclock queue interface
abstract class TimeclockQueue {
  /// Add clock-in operation to queue
  Future<String> queueClockIn({
    required String clientEventId,
    required String workerId,
    required String jobId,
    required DateTime timestamp,
    required LocationResult location,
    String? notes,
  });

  /// Add clock-out operation to queue
  Future<String> queueClockOut({
    required String clientEventId,
    required String workerId,
    required String jobId,
    required DateTime timestamp,
    required LocationResult location,
    String? notes,
  });

  /// Add start break operation to queue
  Future<String> queueStartBreak({
    required String clientEventId,
    required String workerId,
    required String timeEntryId,
    required DateTime timestamp,
    required String breakType, // 'paid' or 'unpaid'
  });

  /// Add end break operation to queue
  Future<String> queueEndBreak({
    required String clientEventId,
    required String workerId,
    required String breakId,
    required DateTime timestamp,
  });

  /// Add dispute operation to queue
  Future<String> queueDispute({
    required String clientEventId,
    required String workerId,
    required String timeEntryId,
    required String disputeReason,
  });

  /// Get all queued operations for a worker
  Future<List<QueuedOperation>> getQueuedOperations({
    required String workerId,
    bool includeCompleted = false,
  });

  /// Get pending operations count for worker
  Future<int> getPendingCount({required String workerId});

  /// Process queue (attempt to sync all pending operations)
  /// Returns number of successfully synced operations
  Future<int> processQueue({required String workerId});

  /// Process single operation
  /// Returns true if successful
  Future<bool> processOperation({required String operationId});

  /// Cancel queued operation
  Future<void> cancelOperation({required String operationId});

  /// Clear completed operations older than specified duration
  Future<void> clearCompleted({Duration olderThan = const Duration(days: 7)});

  /// Check if worker has active clock-in (local or synced)
  /// Prevents double-punch across devices
  Future<bool> hasActiveClockin({required String workerId});

  /// Stream of queue status for worker
  /// Emits updates when queue changes
  Stream<QueueStatus> watchQueueStatus({required String workerId});
}

/// Queue status summary
class QueueStatus {
  final int pending;
  final int syncing;
  final int failed;
  final int completed;

  QueueStatus({
    required this.pending,
    required this.syncing,
    required this.failed,
    required this.completed,
  });

  int get total => pending + syncing + failed;
  bool get hasErrors => failed > 0;
  bool get isSyncing => syncing > 0;
  bool get isEmpty => total == 0;

  String get statusMessage {
    if (isEmpty) return 'All synced';
    if (isSyncing) return 'Syncing $syncing...';
    if (hasErrors) return '$failed failed - will retry';
    return '$pending pending';
  }
}

/// Timeclock queue exceptions
class QueueException implements Exception {
  final String message;
  final QueueExceptionType type;

  QueueException(this.message, this.type);

  @override
  String toString() => 'QueueException: $message';
}

/// Exception types
enum QueueExceptionType {
  /// Duplicate operation detected (same clientEventId)
  duplicate,

  /// Active clock-in already exists
  doublePunch,

  /// Operation not found in queue
  notFound,

  /// Queue storage error
  storageError,

  /// Network error during sync
  networkError,

  /// Server rejected operation
  serverError,

  /// Unknown error
  unknown,
}

/// Provider for timeclock queue
/// Implementation will be provided by concrete class
final timeclockQueueProvider = Provider<TimeclockQueue>((ref) {
  throw UnimplementedError(
    'TimeclockQueue provider must be overridden with concrete implementation',
  );
});

/// Provider for queue status stream
final queueStatusProvider = StreamProvider.family<QueueStatus, String>((
  ref,
  workerId,
) {
  final queue = ref.watch(timeclockQueueProvider);
  return queue.watchQueueStatus(workerId: workerId);
});
