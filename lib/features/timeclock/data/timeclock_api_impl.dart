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

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/errors/error_mapper.dart';
import 'package:sierra_painting/features/timeclock/domain/timeclock_api.dart';

/// Implementation of TimeclockApi using Firebase Callable Functions
class TimeclockApiImpl implements TimeclockApi {
  final FirebaseFunctions _functions;

  TimeclockApiImpl({required FirebaseFunctions functions})
      : _functions = functions;

  @override
  Future<ClockInResponse> clockIn(ClockInRequest request) async {
    try {
      final callable = _functions.httpsCallable('clockIn');
      final result = await callable.call<Map<String, dynamic>>(
        request.toJson(),
      );

      return ClockInResponse.fromJson(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _mapFunctionError(e);
    } catch (e) {
      throw Exception('Failed to clock in: $e');
    }
  }

  @override
  Future<ClockOutResponse> clockOut(ClockOutRequest request) async {
    try {
      final callable = _functions.httpsCallable('clockOut');
      final result = await callable.call<Map<String, dynamic>>(
        request.toJson(),
      );

      return ClockOutResponse.fromJson(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw _mapFunctionError(e);
    } catch (e) {
      throw Exception('Failed to clock out: $e');
    }
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

/// Provider for TimeclockApi
final timeclockApiProvider = Provider<TimeclockApi>((ref) {
  final functions = FirebaseFunctions.instanceFor(region: 'us-east4');
  return TimeclockApiImpl(functions: functions);
});
