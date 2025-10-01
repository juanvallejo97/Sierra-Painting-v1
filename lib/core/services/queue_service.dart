import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:sierra_painting/core/models/queue_item.dart';

/// Provider for the queue box (Hive)
final queueBoxProvider = FutureProvider<Box<QueueItem>>((ref) async {
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(QueueItemAdapter());
  }
  return await Hive.openBox<QueueItem>('queue');
});

/// Service for managing offline queue
class QueueService {
  final Box<QueueItem> box;

  QueueService(this.box);

  Future<void> addToQueue(QueueItem item) async {
    await box.add(item);
  }

  List<QueueItem> getPendingItems() {
    return box.values.where((item) => !item.processed).toList();
  }

  Future<void> markAsProcessed(int index) async {
    final item = box.getAt(index);
    if (item != null) {
      item.processed = true;
      await box.putAt(index, item);
    }
  }

  Future<void> removeItem(int index) async {
    await box.deleteAt(index);
  }
}

final queueServiceProvider = Provider<QueueService?>((ref) {
  final boxAsync = ref.watch(queueBoxProvider);
  return boxAsync.when(
    data: (box) => QueueService(box),
    loading: () => null,
    error: (_, __) => null,
  );
});
