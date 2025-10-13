/// Offline Queue Service
///
/// PURPOSE:
/// Queues operations for later sync when offline.
/// Ensures no data loss and automatic replay when connectivity is restored.
///
/// FEATURES:
/// - Persistent queue (survives app restart)
/// - Automatic replay on connectivity restoration
/// - Deduplication via clientEventId
/// - Exponential backoff retry
/// - Real-time pending count stream
///
/// USAGE:
/// ```dart
/// // Enqueue operation
/// await offlineQueue.enqueue(() async {
///   return api.clockIn(ClockInRequest(..., clientEventId: eventId));
/// }, key: eventId);
///
/// // Show pending sync UI
/// final count = ref.watch(offlineQueuePendingCountProvider);
/// if (count > 0) PendingSyncChip(count: count);
/// ```
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Operation to be queued
class QueuedOperation {
  final String id;
  final String type; // 'clockIn', 'clockOut', etc.
  final Map<String, dynamic> data;
  final DateTime queuedAt;
  final int retryCount;
  final DateTime? lastAttemptAt;

  QueuedOperation({
    required this.id,
    required this.type,
    required this.data,
    required this.queuedAt,
    this.retryCount = 0,
    this.lastAttemptAt,
  });

  QueuedOperation copyWith({int? retryCount, DateTime? lastAttemptAt}) {
    return QueuedOperation(
      id: id,
      type: type,
      data: data,
      queuedAt: queuedAt,
      retryCount: retryCount ?? this.retryCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'data': data,
      'queuedAt': queuedAt.toIso8601String(),
      'retryCount': retryCount,
      if (lastAttemptAt != null)
        'lastAttemptAt': lastAttemptAt!.toIso8601String(),
    };
  }

  factory QueuedOperation.fromJson(Map<String, dynamic> json) {
    return QueuedOperation(
      id: json['id'] as String,
      type: json['type'] as String,
      data: json['data'] as Map<String, dynamic>,
      queuedAt: DateTime.parse(json['queuedAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
      lastAttemptAt: json['lastAttemptAt'] != null
          ? DateTime.parse(json['lastAttemptAt'] as String)
          : null,
    );
  }
}

/// Offline Queue Service Interface
abstract class OfflineQueue {
  /// Enqueue operation for later execution
  ///
  /// - [operation]: Function to execute when online
  /// - [key]: Unique identifier for deduplication (e.g., clientEventId)
  /// - [type]: Operation type for logging/debugging
  Future<void> enqueue(
    Future<void> Function() operation, {
    required String key,
    required String type,
    Map<String, dynamic>? metadata,
  });

  /// Stream of pending operations count
  Stream<int> pendingCount();

  /// Manually trigger replay (usually happens automatically on connectivity restoration)
  Future<void> replayWhenOnline();

  /// Clear all pending operations (use with caution)
  Future<void> clearAll();
}

/// Minimal implementation (to be fleshed out)
///
/// TODO: Implement with Hive/Isar for persistence
/// TODO: Add connectivity listener for automatic replay
/// TODO: Add exponential backoff for retries
/// TODO: Add transaction-like semantics for complex operations
class OfflineQueueImpl implements OfflineQueue {
  final StreamController<int> _countController =
      StreamController<int>.broadcast();
  final List<QueuedOperation> _queue = [];

  @override
  Future<void> enqueue(
    Future<void> Function() operation, {
    required String key,
    required String type,
    Map<String, dynamic>? metadata,
  }) async {
    // TODO: Check for duplicates via key (clientEventId)
    // TODO: Persist to Hive/Isar
    // TODO: Execute immediately if online, otherwise queue

    final queuedOp = QueuedOperation(
      id: key,
      type: type,
      data: metadata ?? {},
      queuedAt: DateTime.now(),
    );

    _queue.add(queuedOp);
    _countController.add(_queue.length);

    // Try to execute immediately if online
    // await _attemptExecution(operation, queuedOp);
  }

  @override
  Stream<int> pendingCount() {
    return _countController.stream;
  }

  @override
  Future<void> replayWhenOnline() async {
    // TODO: Iterate queue, retry failed operations with exponential backoff
    // TODO: Remove successful operations from queue
    // TODO: Update _countController
  }

  @override
  Future<void> clearAll() async {
    _queue.clear();
    _countController.add(0);
  }

  /// Attempt to execute operation with retry logic
  // ignore: unused_element
  Future<void> _attemptExecution(
    Future<void> Function() operation,
    QueuedOperation queuedOp,
  ) async {
    try {
      await operation();
      // Success: remove from queue
      _queue.removeWhere((op) => op.id == queuedOp.id);
      _countController.add(_queue.length);
    } catch (e) {
      // Failed: increment retry count, apply backoff
      final updated = queuedOp.copyWith(
        retryCount: queuedOp.retryCount + 1,
        lastAttemptAt: DateTime.now(),
      );
      final index = _queue.indexWhere((op) => op.id == queuedOp.id);
      if (index != -1) {
        _queue[index] = updated;
      }
    }
  }
}

/// Provider for OfflineQueue
final offlineQueueProvider = Provider<OfflineQueue>((ref) {
  return OfflineQueueImpl();
});

/// Provider for pending count stream
final offlineQueuePendingCountProvider = StreamProvider<int>((ref) {
  final queue = ref.watch(offlineQueueProvider);
  return queue.pendingCount();
});
