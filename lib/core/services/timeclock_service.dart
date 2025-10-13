/// Timeclock Service
///
/// Calls Cloud Functions in us-east4 region for Clock In/Out operations.
/// Includes timeout handling and error mapping.
library;

import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TimeclockService {
  final FirebaseFunctions _fns;

  TimeclockService._(this._fns);

  /// Factory for us-east4 region (where our functions are deployed)
  factory TimeclockService.usEast4() =>
      TimeclockService._(FirebaseFunctions.instanceFor(region: 'us-east4'));

  /// Clock In to a job
  ///
  /// Throws:
  /// - Exception with specific error codes on failure
  /// - TimeoutException if call exceeds 8 seconds
  Future<Map<String, dynamic>> clockIn({
    required String jobId,
    required double lat,
    required double lng,
    required double accuracy,
    required String clientEventId,
    String? notes,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('UNAUTHENTICATED');

    final callable = _fns.httpsCallable('clockIn');
    try {
      final res = await callable
          .call({
            'jobId': jobId,
            'lat': lat,
            'lng': lng,
            'accuracy': accuracy,
            'clientEventId': clientEventId,
            if (notes != null && notes.isNotEmpty) 'notes': notes,
          })
          .timeout(const Duration(seconds: 8));

      return Map<String, dynamic>.from(res.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw _mapError(e);
    } on TimeoutException {
      throw Exception('CLOCKIN_TIMEOUT');
    }
  }

  /// Clock Out from current active entry
  ///
  /// Throws:
  /// - Exception with specific error codes on failure
  /// - TimeoutException if call exceeds 8 seconds
  Future<Map<String, dynamic>> clockOut({
    required String timeEntryId,
    required double lat,
    required double lng,
    required double accuracy,
    required String clientEventId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('UNAUTHENTICATED');

    final callable = _fns.httpsCallable('clockOut');
    try {
      final res = await callable
          .call({
            'timeEntryId': timeEntryId,
            'lat': lat,
            'lng': lng,
            'accuracy': accuracy,
            'clientEventId': clientEventId,
          })
          .timeout(const Duration(seconds: 8));

      return Map<String, dynamic>.from(res.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw _mapError(e);
    } on TimeoutException {
      throw Exception('CLOCKOUT_TIMEOUT');
    }
  }

  /// Map Firebase Functions errors to user-friendly exception codes
  Exception _mapError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'failed-precondition':
        final msg = e.message ?? '';
        if (msg.contains('Already clocked in')) {
          return Exception('ALREADY_CLOCKED_IN');
        }
        if (msg.contains('Outside geofence')) {
          return Exception('OUTSIDE_GEOFENCE');
        }
        if (msg.contains('Not assigned')) {
          return Exception('NOT_ASSIGNED');
        }
        if (msg.contains('GPS accuracy')) {
          return Exception('GPS_ACCURACY_LOW');
        }
        return Exception('FAILED_PRECONDITION: $msg');

      case 'permission-denied':
        return Exception('PERMISSION_DENIED');

      case 'unauthenticated':
        return Exception('UNAUTHENTICATED');

      case 'invalid-argument':
        return Exception('INVALID_ARGUMENT: ${e.message}');

      case 'not-found':
        final msg = e.message ?? '';
        if (msg.contains('Job not found')) {
          return Exception('JOB_NOT_FOUND');
        }
        if (msg.contains('Time entry not found')) {
          return Exception('TIME_ENTRY_NOT_FOUND');
        }
        return Exception('NOT_FOUND: $msg');

      default:
        return Exception('UNKNOWN_FUNCTIONS_ERROR: ${e.code}');
    }
  }

  /// User-friendly error messages for UI display
  static String userMessage(String errorCode) {
    switch (errorCode) {
      case 'ALREADY_CLOCKED_IN':
        return 'You are already clocked in to a job. Clock out first.';
      case 'OUTSIDE_GEOFENCE':
        return 'You are too far from the job site. Move closer and try again.';
      case 'NOT_ASSIGNED':
        return 'You are not assigned to this job. Contact your manager.';
      case 'GPS_ACCURACY_LOW':
        return 'GPS signal is too weak. Please wait for better signal.';
      case 'JOB_NOT_FOUND':
        return 'Job not found. It may have been deleted.';
      case 'TIME_ENTRY_NOT_FOUND':
        return 'Time entry not found. You may not be clocked in.';
      case 'UNAUTHENTICATED':
        return 'Please sign in to continue.';
      case 'PERMISSION_DENIED':
        return 'You don\'t have permission to perform this action.';
      case 'CLOCKIN_TIMEOUT':
      case 'CLOCKOUT_TIMEOUT':
        return 'Request timed out. Check your internet connection and try again.';
      default:
        return 'Unable to complete. Please try again.';
    }
  }
}
