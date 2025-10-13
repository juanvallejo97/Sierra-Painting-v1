/// Timeclock API Implementation
///
/// PURPOSE:
/// Concrete implementation of TimeclockApi using Firebase Callable Functions.
/// Calls server-side geofence validation for clock in/out operations.
///
/// DEPENDENCIES:
/// - Firebase Cloud Functions (clockIn, clockOut)
/// - Firebase Auth (for authentication token)
///
/// ERROR HANDLING:
/// - Maps Firebase function errors to user-friendly exceptions
/// - Preserves error codes for client-side handling
library;

import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/errors/error_mapper.dart';
import 'package:sierra_painting/core/services/offline_queue.dart';
import 'package:sierra_painting/features/timeclock/domain/timeclock_api.dart';

/// Exception thrown when operation is queued for offline sync
class OperationQueuedException implements Exception {
  final String message;
  OperationQueuedException(this.message);

  @override
  String toString() => message;
}

/// Implementation of TimeclockApi using Firebase Callable Functions
class TimeclockApiImpl implements TimeclockApi {
  final FirebaseFunctions _functions;
  final OfflineQueue? _offlineQueue;

  TimeclockApiImpl({
    required FirebaseFunctions functions,
    OfflineQueue? offlineQueue,
  }) : _functions = functions,
       _offlineQueue = offlineQueue;

  @override
  Future<ClockInResponse> clockIn(ClockInRequest request) async {
    try {
      final callable = _functions.httpsCallable('clockIn');
      final result = await callable
          .call<Map<String, dynamic>>(request.toJson())
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception(
              'Clock in request timed out. Please check your connection and try again.',
            ),
          );

      return ClockInResponse.fromJson(result.data);
    } on FirebaseFunctionsException catch (e) {
      // Network/timeout errors should be queued for offline sync
      if (_isNetworkError(e) && _offlineQueue != null) {
        await _offlineQueue.enqueue(
          () async {
            final callable = _functions.httpsCallable('clockIn');
            await callable.call<Map<String, dynamic>>(request.toJson());
          },
          key: request.clientEventId,
          type: 'clockIn',
          metadata: request.toJson(),
        );
        throw OperationQueuedException(
          'Clock in queued for sync. Will retry when connection is restored.',
        );
      }
      // Validation errors (geofence, permissions, etc.) should fail immediately
      throw _mapFunctionError(e);
    } catch (e) {
      // Other errors
      if (e is OperationQueuedException) rethrow;
      throw Exception('Failed to clock in: $e');
    }
  }

  @override
  Future<ClockOutResponse> clockOut(ClockOutRequest request) async {
    try {
      final callable = _functions.httpsCallable('clockOut');
      final result = await callable
          .call<Map<String, dynamic>>(request.toJson())
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception(
              'Clock out request timed out. Please check your connection and try again.',
            ),
          );

      return ClockOutResponse.fromJson(result.data);
    } on FirebaseFunctionsException catch (e) {
      // Network/timeout errors should be queued for offline sync
      if (_isNetworkError(e) && _offlineQueue != null) {
        await _offlineQueue.enqueue(
          () async {
            final callable = _functions.httpsCallable('clockOut');
            await callable.call<Map<String, dynamic>>(request.toJson());
          },
          key: request.clientEventId,
          type: 'clockOut',
          metadata: request.toJson(),
        );
        throw OperationQueuedException(
          'Clock out queued for sync. Will retry when connection is restored.',
        );
      }
      // Validation errors should fail immediately
      throw _mapFunctionError(e);
    } catch (e) {
      // Other errors
      if (e is OperationQueuedException) rethrow;
      throw Exception('Failed to clock out: $e');
    }
  }

  /// Check if error is network-related (should be queued for retry)
  bool _isNetworkError(FirebaseFunctionsException error) {
    // Network errors that should trigger offline queue
    return error.code == 'unavailable' ||
        error.code == 'deadline-exceeded' ||
        error.code == 'network-request-failed' ||
        error.message?.contains('network') == true ||
        error.message?.contains('timeout') == true;
  }

  /// Map Firebase Functions errors to user-friendly exceptions
  /// Uses centralized ErrorMapper for consistent UX
  Exception _mapFunctionError(FirebaseFunctionsException error) {
    // Use ErrorMapper for specific error messages when available
    final mappedMessage = error.message != null
        ? ErrorMapper.mapException(Exception(error.message))
        : ErrorMapper.mapFirebaseError(error.code);

    return Exception(mappedMessage);
  }
}

/// Provider for TimeclockApi with offline queue support
final timeclockApiProvider = Provider<TimeclockApi>((ref) {
  final functions = FirebaseFunctions.instanceFor(region: 'us-east4');
  final offlineQueue = ref.watch(offlineQueueProvider);
  return TimeclockApiImpl(functions: functions, offlineQueue: offlineQueue);
});
