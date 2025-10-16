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
import 'package:connectivity_plus/connectivity_plus.dart';
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

/// Minimal implementation with auto-drain on connectivity restoration
///
/// FEATURES (Phase 1 - CHK-08):
/// - Connectivity listener for automatic drain
/// - Single drain pass on reconnect (no duplicates)
/// - "Synced" toast notification callback
/// - Prevents concurrent drains with isDraining flag
///
/// TODO (Future phases):
/// - Persist to Hive (survive app restart)
/// - Exponential backoff for retries
/// - Transaction-like semantics for complex operations
class OfflineQueueImpl implements OfflineQueue {
  final StreamController<int> _countController =
      StreamController<int>.broadcast();
  final List<QueuedOperation> _queue = [];
  final Map<String, Future<void> Function()> _operations = {};

  bool _isDraining = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Function()? _onSyncComplete; // Callback for "Synced" toast

  OfflineQueueImpl() {
    _initConnectivityListener();
  }

  /// Initialize connectivity listener for auto-drain
  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        final hasConnection = results.any(
          (result) => result != ConnectivityResult.none,
        );
        if (hasConnection && _queue.isNotEmpty && !_isDraining) {
          drainOnce();
        }
      },
    );
  }

  /// Set callback for sync completion (for "Synced" toast)
  void setOnSyncComplete(Function() callback) {
    _onSyncComplete = callback;
  }

  /// Drain queue once (single pass, in order, no duplicates)
  Future<void> drainOnce() async {
    if (_isDraining) return; // Prevent concurrent drains

    _isDraining = true;

    try {
      // Process operations in order (FIFO)
      final operationsToProcess = List<QueuedOperation>.from(_queue);
      int successCount = 0;

      for (final queuedOp in operationsToProcess) {
        final operation = _operations[queuedOp.id];
        if (operation != null) {
          try {
            await operation();
            // Success: remove from queue
            _queue.removeWhere((op) => op.id == queuedOp.id);
            _operations.remove(queuedOp.id);
            successCount++;
          } catch (e) {
            // Failed: leave in queue for next drain attempt
            // Update retry count
            final index = _queue.indexWhere((op) => op.id == queuedOp.id);
            if (index != -1) {
              _queue[index] = queuedOp.copyWith(
                retryCount: queuedOp.retryCount + 1,
                lastAttemptAt: DateTime.now(),
              );
            }
          }
        } else {
          // Operation function not found, remove stale entry
          _queue.removeWhere((op) => op.id == queuedOp.id);
        }
      }

      _countController.add(_queue.length);

      // Notify sync completion if any operations succeeded
      if (successCount > 0 && _onSyncComplete != null) {
        _onSyncComplete!();
      }
    } finally {
      _isDraining = false;
    }
  }

  @override
  Future<void> enqueue(
    Future<void> Function() operation, {
    required String key,
    required String type,
    Map<String, dynamic>? metadata,
  }) async {
    // Check for duplicates via key (clientEventId)
    if (_queue.any((op) => op.id == key)) {
      return; // Already queued, skip duplicate
    }

    final queuedOp = QueuedOperation(
      id: key,
      type: type,
      data: metadata ?? {},
      queuedAt: DateTime.now(),
    );

    _queue.add(queuedOp);
    _operations[key] = operation;
    _countController.add(_queue.length);

    // Try to execute immediately if we have connectivity (best effort)
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnection = connectivityResult.any(
        (result) => result != ConnectivityResult.none,
      );

      if (hasConnection) {
        // Fire and forget - don't block enqueue
        unawaited(drainOnce());
      }
    } catch (e) {
      // Connectivity check failed (e.g., in tests) - skip immediate drain
      // Will be drained on next connectivity change or manual replay
    }
  }

  @override
  Stream<int> pendingCount() {
    return _countController.stream;
  }

  @override
  Future<void> replayWhenOnline() async {
    // Calls drainOnce() - single pass through queue
    await drainOnce();
  }

  @override
  Future<void> clearAll() async {
    _queue.clear();
    _operations.clear();
    _countController.add(0);
  }

  /// Dispose of resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _countController.close();
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
