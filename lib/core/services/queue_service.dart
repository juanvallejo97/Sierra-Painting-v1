import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:sierra_painting/core/models/queue_item.dart';

/// Maximum number of items allowed in offline queue
const int maxQueueSize = 100;

/// Number of items at which to show warning to user
const int queueWarningThreshold = 50;

/// Age in days after which old items are auto-expired
const int queueItemExpiryDays = 7;

/// Provider for the queue box (Hive)
final queueBoxProvider = FutureProvider<Box<QueueItem>>((ref) async {
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(QueueItemAdapter());
  }
  return await Hive.openBox<QueueItem>('queue');
});

/// Service for managing offline queue with size limits
///
/// Implements RISK-OFF-001 mitigation:
/// - Max queue size: 100 items
/// - Warning when > 50 items
/// - Auto-expire items older than 7 days
class QueueService {
  final Box<QueueItem> box;

  QueueService(this.box);

  /// Add item to queue if not at max capacity
  ///
  /// Throws [QueueFullException] if queue is at max size
  /// Automatically cleans up old items before adding
  Future<void> addToQueue(QueueItem item) async {
    // Clean up old items first
    await _cleanupOldItems();

    final pendingCount = getPendingItems().length;

    if (pendingCount >= maxQueueSize) {
      throw QueueFullException(
        'Queue is full ($maxQueueSize items). Please sync pending items before adding more.',
      );
    }

    await box.add(item);
  }

  /// Get all pending (unprocessed) items
  List<QueueItem> getPendingItems() {
    return box.values.where((item) => !item.processed).toList();
  }

  /// Get count of pending items
  int getPendingCount() {
    return getPendingItems().length;
  }

  /// Check if queue is near capacity (> 50 items)
  bool shouldShowWarning() {
    return getPendingCount() > queueWarningThreshold;
  }

  /// Check if queue is at max capacity
  bool isFull() {
    return getPendingCount() >= maxQueueSize;
  }

  /// Get percentage of queue filled (0-100)
  double getQueueUsagePercentage() {
    return (getPendingCount() / maxQueueSize * 100).clamp(0, 100);
  }

  /// Mark item as processed
  Future<void> markAsProcessed(int index) async {
    final item = box.getAt(index);
    if (item != null) {
      item.processed = true;
      await box.putAt(index, item);
    }
  }

  /// Remove item from queue
  Future<void> removeItem(int index) async {
    await box.deleteAt(index);
  }

  /// Retry all failed items
  ///
  /// Sets processed = false for all items with errors
  Future<void> retryFailed() async {
    for (var i = 0; i < box.length; i++) {
      final item = box.getAt(i);
      if (item != null && !item.processed && item.retryCount > 0) {
        item.processed = false;
        await box.putAt(i, item);
      }
    }
  }

  /// Clean up items older than [queueItemExpiryDays] days
  ///
  /// Automatically called before adding new items
  Future<int> _cleanupOldItems() async {
    final now = DateTime.now();
    final expiryDate = now.subtract(Duration(days: queueItemExpiryDays));

    int removedCount = 0;
    final itemsToRemove = <int>[];

    // Find indices of expired items
    for (var i = 0; i < box.length; i++) {
      final item = box.getAt(i);
      if (item != null && item.timestamp.isBefore(expiryDate)) {
        itemsToRemove.add(i);
      }
    }

    // Remove in reverse order to maintain indices
    for (final index in itemsToRemove.reversed) {
      await box.deleteAt(index);
      removedCount++;
    }

    return removedCount;
  }

  /// Manually clean up old items (for scheduled cleanup)
  Future<int> cleanupOldItems() async {
    return await _cleanupOldItems();
  }

  /// Clear all processed items
  Future<int> clearProcessed() async {
    int removedCount = 0;
    final itemsToRemove = <int>[];

    // Find indices of processed items
    for (var i = 0; i < box.length; i++) {
      final item = box.getAt(i);
      if (item != null && item.processed) {
        itemsToRemove.add(i);
      }
    }

    // Remove in reverse order to maintain indices
    for (final index in itemsToRemove.reversed) {
      await box.deleteAt(index);
      removedCount++;
    }

    return removedCount;
  }

  /// Get statistics about the queue
  QueueStats getStats() {
    final allItems = box.values.toList();
    final pending = allItems.where((item) => !item.processed).length;
    final processed = allItems.where((item) => item.processed).length;
    final failed = allItems.where((item) => item.retryCount > 0).length;

    return QueueStats(
      total: allItems.length,
      pending: pending,
      processed: processed,
      failed: failed,
      usagePercentage: getQueueUsagePercentage(),
    );
  }
}

/// Statistics about the queue
class QueueStats {
  final int total;
  final int pending;
  final int processed;
  final int failed;
  final double usagePercentage;

  QueueStats({
    required this.total,
    required this.pending,
    required this.processed,
    required this.failed,
    required this.usagePercentage,
  });
}

/// Exception thrown when queue is at max capacity
class QueueFullException implements Exception {
  final String message;

  QueueFullException(this.message);

  @override
  String toString() => 'QueueFullException: $message';
}

final queueServiceProvider = Provider<QueueService?>((ref) {
  final boxAsync = ref.watch(queueBoxProvider);
  return boxAsync.when(
    data: (box) => QueueService(box),
    loading: () => null,
    error: (_, __) => null,
  );
});
