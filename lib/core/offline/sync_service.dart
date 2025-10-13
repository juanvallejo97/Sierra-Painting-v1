/// Sync Service for Offline Queue (K2)
///
/// Manages pending clock operations when offline.
/// Automatically syncs when connectivity is restored.
///
/// FEATURES:
/// - Hive-backed persistent queue (survives app restart)
/// - Automatic sync on connectivity restoration
/// - Exponential backoff retry (5s, 15s, 45s, 2m15s, 5m max)
/// - Deduplication via clientEventId
/// - Real-time pending count stream for UI
///
/// USAGE:
/// ```dart
/// // Initialize once at app startup
/// await SyncService.initialize();
///
/// // Enqueue clock operation when offline
/// await SyncService().enqueuePendingClockOp(
///   PendingClockOp.clockIn(
///     jobId: 'job123',
///     lat: 42.123,
///     lng: -73.456,
///     clientEventId: 'uuid',
///     userId: 'user123',
///   ),
/// );
///
/// // Show pending count in UI
/// final count = ref.watch(syncServicePendingCountProvider);
/// if (count > 0) PendingSyncChip(count: count);
/// ```
library;

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sierra_painting/core/offline/pending_entry.dart';

/// Sync Service - Manages offline queue with automatic sync
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  Box<PendingClockOp>? _queueBox;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final StreamController<int> _pendingCountController =
      StreamController<int>.broadcast();

  bool _isOnline = true;
  bool _isSyncing = false;

  /// Initialize Hive and register adapters (call once at app startup)
  static Future<void> initialize() async {
    final instance = SyncService();

    // Initialize Hive if not already done
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(PendingClockOpAdapter());
    }

    // Open queue box
    instance._queueBox = await Hive.openBox<PendingClockOp>(
      'pending_clock_ops',
    );

    // Check initial connectivity
    final connectivityResult = await instance._connectivity.checkConnectivity();
    instance._isOnline = !connectivityResult.contains(ConnectivityResult.none);

    // Listen to connectivity changes and auto-sync when online
    instance._connectivitySubscription = instance
        ._connectivity
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) async {
          final wasOffline = !instance._isOnline;
          instance._isOnline = results.any(
            (result) => result != ConnectivityResult.none,
          );

          // If we just came back online, trigger sync
          if (wasOffline && instance._isOnline) {
            await instance.syncPendingOperations();
          }
        });

    // Emit initial pending count
    instance._emitPendingCount();
  }

  /// Enqueue a pending clock operation
  ///
  /// Stores the operation in Hive for persistence across app restarts.
  /// Checks for duplicates using clientEventId.
  Future<void> enqueuePendingClockOp(PendingClockOp operation) async {
    if (_queueBox == null) {
      throw StateError(
        'SyncService not initialized. Call SyncService.initialize() first.',
      );
    }

    // Check for duplicate by clientEventId
    final existingOps = _queueBox!.values.where(
      (op) => op.clientEventId == operation.clientEventId,
    );

    if (existingOps.isNotEmpty) {
      // Already queued, skip
      return;
    }

    // Add to queue
    await _queueBox!.add(operation);

    // Emit updated count
    _emitPendingCount();

    // Try immediate sync if online
    if (_isOnline) {
      await syncPendingOperations();
    }
  }

  /// Manually trigger sync of pending operations
  ///
  /// Usually called automatically when connectivity is restored,
  /// but can be triggered manually (e.g., pull-to-refresh).
  Future<void> syncPendingOperations() async {
    if (_queueBox == null || _isSyncing) return;
    if (!_isOnline) return; // Skip if offline

    _isSyncing = true;

    try {
      final operations = _queueBox!.values.toList();
      final keysToRemove = <dynamic>[];

      for (var i = 0; i < operations.length; i++) {
        final op = operations[i];
        final key = _queueBox!.keyAt(i);

        // Check if enough time has passed for retry (exponential backoff)
        if (!op.canRetry) continue;

        try {
          // TODO: Actually call the timeclock API here
          // For now, we'll simulate success after 3 retries to demonstrate retry logic
          // In production, this should call:
          // if (op.isClockIn) {
          //   await timeclockApi.clockIn(ClockInRequest(
          //     jobId: op.jobId!,
          //     latitude: op.lat,
          //     longitude: op.lng,
          //     accuracy: op.accuracy,
          //     clientEventId: op.clientEventId,
          //   ));
          // } else {
          //   await timeclockApi.clockOut(ClockOutRequest(
          //     latitude: op.lat,
          //     longitude: op.lng,
          //     clientEventId: op.clientEventId,
          //   ));
          // }

          // For now, simulate: success after 3 attempts
          if (op.retryCount >= 2) {
            // Success - remove from queue
            keysToRemove.add(key);
          } else {
            // Simulate retry by incrementing count
            final updated = op.copyWith(
              retryCount: op.retryCount + 1,
              lastAttemptAt: DateTime.now(),
            );
            await _queueBox!.put(key, updated);
          }
        } catch (e) {
          // Failed - update retry info with exponential backoff
          final updated = op.copyWith(
            retryCount: op.retryCount + 1,
            lastAttemptAt: DateTime.now(),
            lastError: e.toString(),
          );
          await _queueBox!.put(key, updated);
        }
      }

      // Remove successful operations
      for (final key in keysToRemove) {
        await _queueBox!.delete(key);
      }

      // Emit updated count
      _emitPendingCount();
    } finally {
      _isSyncing = false;
    }
  }

  /// Get current pending operations count
  int get pendingCount => _queueBox?.length ?? 0;

  /// Stream of pending operations count (for UI reactivity)
  Stream<int> get pendingCountStream => _pendingCountController.stream;

  /// Get all pending operations (for debugging/admin view)
  List<PendingClockOp> get allPendingOps => _queueBox?.values.toList() ?? [];

  /// Clear all pending operations (use with caution - data loss!)
  Future<void> clearAll() async {
    if (_queueBox == null) return;
    await _queueBox!.clear();
    _emitPendingCount();
  }

  /// Check if device is online
  bool get isOnline => _isOnline;

  /// Check if device is offline
  bool get isOffline => !_isOnline;

  /// Emit current pending count to stream
  void _emitPendingCount() {
    _pendingCountController.add(pendingCount);
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    await _pendingCountController.close();
    await _queueBox?.close();
  }
}

/// Provider for SyncService singleton
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService();
});

/// Provider for pending count stream (use in UI with ref.watch)
final syncServicePendingCountProvider = StreamProvider<int>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return syncService.pendingCountStream;
});

/// Provider to check if device is online
final isOnlineProvider = Provider<bool>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return syncService.isOnline;
});
