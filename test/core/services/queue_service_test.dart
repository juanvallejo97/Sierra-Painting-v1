/// Unit tests for QueueService integration with TimeclockRepository
///
/// PURPOSE:
/// Verify that TimeclockRepository correctly enqueues 'clockIn' operations
/// via QueueService when offline.
///
/// COVERAGE:
/// - TimeclockRepository calls QueueService.addToQueue when offline
/// - QueueItem contains correct operation type ('clockIn')
/// - QueueItem contains correct clientId in data
///
/// NOTE: This test assumes QueueItem uses the 'type' field for operation type.
/// If the production code currently uses 'operation' instead of 'type' in the
/// QueueItem constructor, that is a bug that needs to be fixed separately.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:sierra_painting/core/models/queue_item.dart';
import 'package:sierra_painting/core/network/api_client.dart';
import 'package:sierra_painting/core/services/queue_service.dart';
import 'package:sierra_painting/core/utils/result.dart';
import 'package:sierra_painting/features/timeclock/data/timeclock_repository.dart';

/// Fake QueueService that captures enqueued items for testing
class FakeQueueService implements QueueService {
  final List<QueueItem> enqueuedItems = [];

  @override
  Future<void> addToQueue(QueueItem item) async {
    enqueuedItems.add(item);
  }

  // Implement other required methods as no-ops for testing
  @override
  List<QueueItem> getPendingItems() => enqueuedItems;

  @override
  int getPendingCount() => enqueuedItems.length;

  @override
  bool shouldShowWarning() => false;

  @override
  bool isFull() => false;

  @override
  double getQueueUsagePercentage() => 0.0;

  @override
  Future<void> markAsProcessed(int index) async {}

  @override
  Future<void> removeItem(int index) async {}

  @override
  Future<void> retryFailed() async {}

  @override
  Future<int> cleanupOldItems() async => 0;

  @override
  Future<int> clearProcessed() async => 0;

  @override
  QueueStats getStats() => QueueStats(
    total: 0,
    pending: 0,
    processed: 0,
    failed: 0,
    usagePercentage: 0.0,
  );

  // Hive box property - not used in our test but must match the real signature
  @override
  Box<QueueItem> get box =>
      throw UnimplementedError('Not used in this test path');
}

/// Fake ApiClient for testing
class FakeApiClient implements ApiClient {
  @override
  Future<Result<T, ApiError>> call<T>({
    required String functionName,
    Map<String, dynamic>? data,
    Map<String, String>? headers,
    int? maxRetries,
    Duration? timeout,
    T Function(Map<String, dynamic> json)? fromJson,
  }) async {
    // Return a trivial success for tests; adjust if a specific flow is asserted.
    final responseData = <String, dynamic>{
      "success": true,
      "entryId": "test-entry-id",
    };
    if (fromJson != null) {
      return Result.success(fromJson(responseData));
    }
    return Result.success(responseData as T);
  }
}

/// Fake Firestore for testing
class FakeFirestore extends Fake implements FirebaseFirestore {}

void main() {
  group('TimeclockRepository QueueService Integration', () {
    late FakeQueueService fakeQueueService;
    late TimeclockRepository repository;
    late FakeApiClient fakeApiClient;
    late FakeFirestore fakeFirestore;

    setUp(() {
      fakeQueueService = FakeQueueService();
      fakeApiClient = FakeApiClient();
      fakeFirestore = FakeFirestore();

      repository = TimeclockRepository(
        apiClient: fakeApiClient,
        firestore: fakeFirestore,
        queueService: fakeQueueService,
      );
    });

    test(
      'repository enqueues clockIn operation via QueueService when offline',
      () async {
        // Arrange
        const jobId = 'test-job-123';

        // Act
        final result = await repository.clockIn(
          jobId: jobId,
          isOnline: false, // Force offline mode
        );

        // Assert - Verify QueueService.addToQueue was called
        expect(result.isSuccess, isTrue);
        expect(fakeQueueService.enqueuedItems.length, 1);

        final enqueuedItem = fakeQueueService.enqueuedItems.first;
        // Verify operation type is 'clockIn'
        expect(enqueuedItem.type, 'clockIn');
      },
    );

    test('repository enqueues clientId in QueueItem data', () async {
      // Arrange
      const jobId = 'test-job-456';

      // Act
      final result = await repository.clockIn(jobId: jobId, isOnline: false);

      // Assert - Verify clientId is captured in data
      expect(result.isSuccess, isTrue);
      expect(fakeQueueService.enqueuedItems.length, 1);

      final enqueuedItem = fakeQueueService.enqueuedItems.first;
      expect(enqueuedItem.data, contains('clientId'));
      expect(enqueuedItem.data['clientId'], isNotEmpty);
      expect(enqueuedItem.data['clientId'], isA<String>());

      // Verify clientId matches the QueueItem id
      expect(enqueuedItem.id, enqueuedItem.data['clientId']);
    });

    test('clockIn does not enqueue when online', () async {
      // Arrange
      const jobId = 'test-job-online';

      // Act
      final result = await repository.clockIn(jobId: jobId, isOnline: true);

      // Assert - When online, ApiClient.call is invoked (returns success)
      // This confirms the offline queue path is not taken
      expect(result.isSuccess, isTrue);

      // Verify queue was not used
      expect(fakeQueueService.enqueuedItems.length, 0);
    });
  });
}
