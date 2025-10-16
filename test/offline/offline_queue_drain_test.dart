/// Unit tests for offline queue drain functionality
///
/// PURPOSE:
/// Verify that the offline queue correctly drains operations in order
/// with no duplicates when connectivity is restored.

import 'package:flutter_test/flutter_test.dart';
import 'package:sierra_painting/core/services/offline_queue.dart';

void main() {
  group('Offline Queue Drain Tests', () {
    late OfflineQueueImpl queue;

    setUp(() {
      queue = OfflineQueueImpl();
    });

    tearDown(() {
      queue.dispose();
    });

    test('drainOnce() processes operations in FIFO order', () async {
      final executionOrder = <String>[];

      // Enqueue three operations
      await queue.enqueue(
        () async {
          executionOrder.add('op1');
        },
        key: 'op1',
        type: 'test',
      );

      await queue.enqueue(
        () async {
          executionOrder.add('op2');
        },
        key: 'op2',
        type: 'test',
      );

      await queue.enqueue(
        () async {
          executionOrder.add('op3');
        },
        key: 'op3',
        type: 'test',
      );

      // Drain queue
      await queue.drainOnce();

      // Verify order
      expect(executionOrder, ['op1', 'op2', 'op3']);
    });

    test('drainOnce() removes successful operations from queue', () async {
      int callCount = 0;

      await queue.enqueue(
        () async {
          callCount++;
        },
        key: 'op1',
        type: 'test',
      );

      // First drain
      await queue.drainOnce();
      expect(callCount, 1);

      // Second drain should not execute operation again
      await queue.drainOnce();
      expect(callCount, 1); // Still 1, not 2
    });

    test('drainOnce() prevents duplicate enqueues via key', () async {
      int callCount = 0;

      await queue.enqueue(
        () async {
          callCount++;
        },
        key: 'duplicate-key',
        type: 'test',
      );

      // Try to enqueue again with same key
      await queue.enqueue(
        () async {
          callCount++;
        },
        key: 'duplicate-key',
        type: 'test',
      );

      // Drain should only execute once
      await queue.drainOnce();
      expect(callCount, 1);
    });

    test('drainOnce() leaves failed operations in queue', () async {
      int successCount = 0;
      int failureAttempts = 0;

      // Success operation
      await queue.enqueue(
        () async {
          successCount++;
        },
        key: 'success',
        type: 'test',
      );

      // Failure operation
      await queue.enqueue(
        () async {
          failureAttempts++;
          throw Exception('Simulated failure');
        },
        key: 'failure',
        type: 'test',
      );

      // First drain
      await queue.drainOnce();
      expect(successCount, 1);
      expect(failureAttempts, 1);

      // Second drain should retry failed operation
      await queue.drainOnce();
      expect(successCount, 1); // Still 1
      expect(failureAttempts, 2); // Incremented to 2
    });

    test('isDraining prevents concurrent drains', () async {
      int callCount = 0;

      await queue.enqueue(
        () async {
          callCount++;
          // Simulate slow operation
          await Future.delayed(const Duration(milliseconds: 100));
        },
        key: 'slow-op',
        type: 'test',
      );

      // Start first drain (doesn't await)
      final drain1 = queue.drainOnce();

      // Try to start second drain immediately
      final drain2 = queue.drainOnce();

      // Wait for both
      await Future.wait([drain1, drain2]);

      // Should only execute once due to isDraining flag
      expect(callCount, 1);
    });

    test('clearAll() removes all operations', () async {
      int callCount = 0;

      await queue.enqueue(
        () async {
          callCount++;
        },
        key: 'op1',
        type: 'test',
      );

      await queue.enqueue(
        () async {
          callCount++;
        },
        key: 'op2',
        type: 'test',
      );

      // Clear before drain
      await queue.clearAll();

      // Drain should do nothing
      await queue.drainOnce();
      expect(callCount, 0);
    });

    test('setOnSyncComplete callback fires after successful drain', () async {
      bool syncCompleted = false;

      queue.setOnSyncComplete(() {
        syncCompleted = true;
      });

      await queue.enqueue(
        () async {
          // Success
        },
        key: 'op1',
        type: 'test',
      );

      await queue.drainOnce();

      expect(syncCompleted, true);
    });

    test('setOnSyncComplete callback does not fire if all operations fail',
        () async {
      bool syncCompleted = false;

      queue.setOnSyncComplete(() {
        syncCompleted = true;
      });

      await queue.enqueue(
        () async {
          throw Exception('Failure');
        },
        key: 'failure',
        type: 'test',
      );

      await queue.drainOnce();

      expect(syncCompleted, false);
    });
  });
}
