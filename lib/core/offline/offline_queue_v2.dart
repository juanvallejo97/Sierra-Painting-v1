/// PHASE 2: SKELETON CODE - Offline Queue V2
///
/// PURPOSE:
/// - Enhanced offline operation queue with optimistic UI updates
/// - Conflict resolution strategies (server wins, client wins, manual)
/// - Operation prioritization (critical ops first)
/// - Retry with exponential backoff
/// - Network state awareness
/// - Undo support for queued operations

library offline_queue_v2;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:sierra_painting/core/offline/hive_encryption.dart';

// ============================================================================
// DATA STRUCTURES
// ============================================================================

enum OperationType {
  create,
  update,
  delete,
}

enum OperationPriority {
  critical, // Time-sensitive (clock in/out)
  high, // Important (invoice payment)
  normal, // Standard operations
  low, // Background sync
}

enum OperationStatus {
  pending, // Not yet attempted
  inProgress, // Currently syncing
  completed, // Successfully synced
  failed, // Failed after retries
  cancelled, // User cancelled
}

enum ConflictResolution {
  serverWins, // Discard local changes
  clientWins, // Override server data
  merge, // Attempt to merge (custom logic)
  manual, // Ask user to resolve
}

// ============================================================================
// QUEUED OPERATION
// ============================================================================

class QueuedOperation {
  final String id;
  final String idempotencyKey; // Prevents duplicate operations
  final OperationType type;
  final String collection;
  final String? documentId;
  final Map<String, dynamic> data;
  final OperationPriority priority;
  final DateTime createdAt;
  final int retryCount;
  final DateTime? nextRetryAt;
  final OperationStatus status;
  final String? errorMessage;
  final ConflictResolution conflictResolution;
  final Map<String, dynamic>? metadata;

  const QueuedOperation({
    required this.id,
    required this.idempotencyKey,
    required this.type,
    required this.collection,
    this.documentId,
    required this.data,
    this.priority = OperationPriority.normal,
    required this.createdAt,
    this.retryCount = 0,
    this.nextRetryAt,
    this.status = OperationStatus.pending,
    this.errorMessage,
    this.conflictResolution = ConflictResolution.serverWins,
    this.metadata,
  });

  /// Generate idempotency key from operation signature
  static String generateIdempotencyKey({
    required OperationType type,
    required String collection,
    String? documentId,
    required Map<String, dynamic> data,
  }) {
    // Create signature from operation details
    final signature = {
      'type': type.name,
      'collection': collection,
      if (documentId != null) 'documentId': documentId,
      'data': data,
    };

    // Hash the signature
    final signatureJson = jsonEncode(signature);
    final bytes = utf8.encode(signatureJson);
    final hash = md5.convert(bytes);

    // Combine UUID with hash for uniqueness
    final uuid = const Uuid().v4();
    return '${uuid}_${hash.toString().substring(0, 16)}';
  }

  QueuedOperation copyWith({
    String? id,
    String? idempotencyKey,
    OperationType? type,
    String? collection,
    String? documentId,
    Map<String, dynamic>? data,
    OperationPriority? priority,
    DateTime? createdAt,
    int? retryCount,
    DateTime? nextRetryAt,
    OperationStatus? status,
    String? errorMessage,
    ConflictResolution? conflictResolution,
    Map<String, dynamic>? metadata,
  }) {
    return QueuedOperation(
      id: id ?? this.id,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      type: type ?? this.type,
      collection: collection ?? this.collection,
      documentId: documentId ?? this.documentId,
      data: data ?? this.data,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      conflictResolution: conflictResolution ?? this.conflictResolution,
      metadata: metadata ?? this.metadata,
    );
  }
}

// ============================================================================
// MAIN OFFLINE QUEUE V2
// ============================================================================

class OfflineQueueV2 {
  // SINGLETON: Private constructor
  OfflineQueueV2._();
  static final instance = OfflineQueueV2._();

  // STATE: Queue storage (in-memory, TODO: persist to Hive)
  final Queue<QueuedOperation> _queue = Queue<QueuedOperation>();
  final Map<String, QueuedOperation> _operationsById = {};

  // STATE: Network status
  bool _isOnline = false;
  Timer? _syncTimer;
  bool _isSyncing = false;

  // STATE: Streams for UI updates
  final _queueController = StreamController<List<QueuedOperation>>.broadcast();
  final _statusController = StreamController<OperationStatus>.broadcast();

  // ============================================================================
  // PUBLIC API
  // ============================================================================

  /// Initialize the queue
  Future<void> initialize() async {
    // Load persisted queue from encrypted Hive box
    try {
      final box = await EncryptedHiveBox.open<Map>('offline_queue_v2');

      // Restore operations from Hive
      for (final item in box.values) {
        // TODO(Phase 3): Deserialize and add to queue
        debugPrint('OfflineQueueV2: Loaded ${box.length} operations from storage');
      }
    } catch (e) {
      debugPrint('OfflineQueueV2: Failed to load from Hive - $e');
    }

    // TODO(Phase 3): Set up network connectivity listener
    // TODO(Phase 3): Start periodic sync timer
    _setupSyncTimer();
  }

  /// Enqueue a new operation
  Future<String> enqueue(QueuedOperation operation) async {
    // TODO(Phase 3): Validate operation
    // TODO(Phase 3): Perform optimistic UI update
    // TODO(Phase 3): Persist to Hive

    _queue.add(operation);
    _operationsById[operation.id] = operation;
    _queueController.add(_queue.toList());

    debugPrint('Enqueued operation: ${operation.id} (${operation.type} ${operation.collection})');

    // Trigger sync if online
    if (_isOnline && !_isSyncing) {
      unawaited(_processQueue());
    }

    return operation.id;
  }

  /// Cancel a pending operation
  Future<void> cancel(String operationId) async {
    final operation = _operationsById[operationId];
    if (operation == null) return;

    // TODO(Phase 3): Only allow cancellation if status is pending or failed
    if (operation.status == OperationStatus.inProgress ||
        operation.status == OperationStatus.completed) {
      throw StateError('Cannot cancel operation in status: ${operation.status}');
    }

    // TODO(Phase 3): Revert optimistic update
    _revertOptimisticUpdate(operation);

    _queue.remove(operation);
    _operationsById.remove(operationId);
    _queueController.add(_queue.toList());

    debugPrint('Cancelled operation: $operationId');
  }

  /// Retry a failed operation
  Future<void> retry(String operationId) async {
    final operation = _operationsById[operationId];
    if (operation == null) return;

    // TODO(Phase 3): Reset retry count and status
    final updated = operation.copyWith(
      status: OperationStatus.pending,
      retryCount: 0,
      nextRetryAt: null,
      errorMessage: null,
    );

    _operationsById[operationId] = updated;
    _queueController.add(_queue.toList());

    debugPrint('Retrying operation: $operationId');

    if (_isOnline && !_isSyncing) {
      unawaited(_processQueue());
    }
  }

  /// Clear all completed operations
  Future<void> clearCompleted() async {
    // TODO(Phase 3): Remove completed operations from Hive
    _queue.removeWhere((op) => op.status == OperationStatus.completed);
    _operationsById.removeWhere((_, op) => op.status == OperationStatus.completed);
    _queueController.add(_queue.toList());

    debugPrint('Cleared completed operations');
  }

  /// Get all operations
  List<QueuedOperation> getAll() {
    return _queue.toList();
  }

  /// Get operations by status
  List<QueuedOperation> getByStatus(OperationStatus status) {
    return _queue.where((op) => op.status == status).toList();
  }

  /// Get pending operation count
  int get pendingCount {
    return _queue.where((op) => op.status == OperationStatus.pending).length;
  }

  /// Stream of queue updates
  Stream<List<QueuedOperation>> get queueStream => _queueController.stream;

  /// Stream of operation status updates
  Stream<OperationStatus> get statusStream => _statusController.stream;

  /// Update network status
  void updateNetworkStatus(bool isOnline) {
    final wasOffline = !_isOnline;
    _isOnline = isOnline;

    debugPrint('Network status: ${isOnline ? "ONLINE" : "OFFLINE"}');

    // Trigger sync when coming back online
    if (wasOffline && isOnline && !_isSyncing) {
      unawaited(_processQueue());
    }
  }

  /// Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _queueController.close();
    _statusController.close();
  }

  // ============================================================================
  // PRIVATE METHODS
  // ============================================================================

  /// Set up periodic sync timer
  void _setupSyncTimer() {
    // TODO(Phase 3): Configure sync interval (e.g., every 30 seconds)
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isOnline && !_isSyncing && _queue.isNotEmpty) {
        unawaited(_processQueue());
      }
    });
  }

  /// Process the operation queue
  Future<void> _processQueue() async {
    if (_isSyncing || !_isOnline || _queue.isEmpty) return;

    _isSyncing = true;

    try {
      // TODO(Phase 3): Sort queue by priority
      final sortedOps = _queue.toList()
        ..sort((a, b) {
          // Sort by priority, then by creation time
          final priorityComparison = b.priority.index.compareTo(a.priority.index);
          if (priorityComparison != 0) return priorityComparison;
          return a.createdAt.compareTo(b.createdAt);
        });

      for (final operation in sortedOps) {
        // Skip if already in progress or completed
        if (operation.status != OperationStatus.pending &&
            operation.status != OperationStatus.failed) {
          continue;
        }

        // Check if ready for retry (exponential backoff)
        if (operation.nextRetryAt != null &&
            DateTime.now().isBefore(operation.nextRetryAt!)) {
          continue;
        }

        await _syncOperation(operation);
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync a single operation
  Future<void> _syncOperation(QueuedOperation operation) async {
    // TODO(Phase 3): Update status to in_progress
    final inProgress = operation.copyWith(status: OperationStatus.inProgress);
    _operationsById[operation.id] = inProgress;
    _queueController.add(_queue.toList());
    _statusController.add(OperationStatus.inProgress);

    try {
      // TODO(Phase 3): Execute Firestore operation based on type
      await _executeOperation(operation);

      // TODO(Phase 3): Mark as completed
      final completed = operation.copyWith(status: OperationStatus.completed);
      _operationsById[operation.id] = completed;
      _queueController.add(_queue.toList());
      _statusController.add(OperationStatus.completed);

      debugPrint('Synced operation: ${operation.id}');
    } catch (e) {
      // TODO(Phase 3): Handle errors and retry logic
      final retryCount = operation.retryCount + 1;
      final maxRetries = 3;

      if (retryCount >= maxRetries) {
        // Max retries exceeded
        final failed = operation.copyWith(
          status: OperationStatus.failed,
          errorMessage: e.toString(),
          retryCount: retryCount,
        );
        _operationsById[operation.id] = failed;
        _statusController.add(OperationStatus.failed);

        debugPrint('Operation failed after $maxRetries retries: ${operation.id}');
      } else {
        // Schedule retry with exponential backoff
        final backoffSeconds = 2 * retryCount; // 2s, 4s, 6s
        final nextRetry = DateTime.now().add(Duration(seconds: backoffSeconds));

        final retry = operation.copyWith(
          status: OperationStatus.pending,
          retryCount: retryCount,
          nextRetryAt: nextRetry,
          errorMessage: e.toString(),
        );
        _operationsById[operation.id] = retry;

        debugPrint('Operation retry scheduled (attempt $retryCount): ${operation.id}');
      }

      _queueController.add(_queue.toList());
    }
  }

  /// Execute the actual Firestore operation
  Future<void> _executeOperation(QueuedOperation operation) async {
    // TODO(Phase 3): Implement Firestore operations
    // final firestore = FirebaseFirestore.instance;
    // final collectionRef = firestore.collection(operation.collection);

    switch (operation.type) {
      case OperationType.create:
        // await collectionRef.add(operation.data);
        break;
      case OperationType.update:
        if (operation.documentId == null) {
          throw ArgumentError('Document ID required for update operation');
        }
        // await collectionRef.doc(operation.documentId).update(operation.data);
        break;
      case OperationType.delete:
        if (operation.documentId == null) {
          throw ArgumentError('Document ID required for delete operation');
        }
        // await collectionRef.doc(operation.documentId).delete();
        break;
    }

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Revert optimistic update
  void _revertOptimisticUpdate(QueuedOperation operation) {
    // TODO(Phase 3): Implement optimistic update reversion
    // This would require tracking the original state before the operation
    debugPrint('Reverting optimistic update for: ${operation.id}');
  }
}
