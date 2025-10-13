/// Error Mapper
///
/// PURPOSE:
/// Centralized mapping of Firebase error codes to user-friendly messages.
/// Ensures consistent, friendly error handling across the app.
///
/// USAGE:
/// ```dart
/// try {
///   await api.clockIn(...);
/// } on FirebaseFunctionsException catch (e) {
///   final message = ErrorMapper.mapFirebaseError(e.code);
///   ScaffoldMessenger.of(context).showSnackBar(
///     SnackBar(content: Text(message)),
///   );
/// }
/// ```
library;

/// Error mapper for Firebase and API errors
class ErrorMapper {
  /// Map Firebase error code to user-friendly message
  static String mapFirebaseError(String code) {
    switch (code) {
      case 'unauthenticated':
        return 'Please sign in again to continue.';

      case 'permission-denied':
        return 'You don\'t have access to perform this action.';

      case 'failed-precondition':
        return 'Action not allowed right now. Please check the requirements.';

      case 'invalid-argument':
        return 'Please check your GPS signal and try again.';

      case 'not-found':
        return 'Requested resource not found.';

      case 'already-exists':
        return 'This resource already exists.';

      case 'resource-exhausted':
        return 'Too many requests. Please try again in a moment.';

      case 'cancelled':
        return 'Operation was cancelled.';

      case 'unknown':
      case 'internal':
        return 'Something went wrong. Please try again.';

      case 'unavailable':
        return 'Service temporarily unavailable. Please try again.';

      case 'deadline-exceeded':
        return 'Request took too long. Please try again.';

      case 'data-loss':
        return 'Data error occurred. Please contact support.';

      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Map exception with message to user-friendly text
  ///
  /// Extracts specific error details when available
  static String mapException(Object error, [String? defaultMessage]) {
    final errorString = error.toString();

    // GPS/Location errors
    if (errorString.contains('GPS accuracy too low') ||
        errorString.contains('accuracy')) {
      final accuracyMatch = RegExp(r'(\d+)m').firstMatch(errorString);
      if (accuracyMatch != null) {
        return 'GPS accuracy is ${accuracyMatch.group(1)}m. Move to an open area for better signal.';
      }
      return 'GPS signal is too weak. Move to an open area and try again.';
    }

    // Geofence errors
    if (errorString.contains('Outside geofence') ||
        errorString.contains('from job site')) {
      final distanceMatch = RegExp(
        r'(\d+\.?\d*)m from job',
      ).firstMatch(errorString);
      if (distanceMatch != null) {
        return 'You are ${distanceMatch.group(1)}m from the job site. Move closer to clock in.';
      }
      return 'You are outside the job site area. Move closer to clock in.';
    }

    // Assignment errors
    if (errorString.contains('Not assigned')) {
      return 'You are not assigned to this job. Contact your manager.';
    }
    if (errorString.contains('Assignment not active')) {
      // Extract start date if available
      final startsMatch = RegExp(r'Starts: (.+)').firstMatch(errorString);
      if (startsMatch != null) {
        return 'This job starts ${startsMatch.group(1)}. Contact your manager if this is incorrect.';
      }
      return 'This job assignment is not active yet.';
    }
    if (errorString.contains('Assignment expired')) {
      return 'This job assignment has ended. Contact your manager.';
    }

    // Clock state errors
    if (errorString.contains('Already clocked in')) {
      return 'You are already clocked in to a job. Clock out first.';
    }
    if (errorString.contains('already clocked out') ||
        errorString.contains('Not clocked in')) {
      return 'You are not currently clocked in to any job.';
    }

    // Auth errors
    if (errorString.contains('Sign in required') ||
        errorString.contains('unauthenticated')) {
      return 'Please sign in to use the timeclock.';
    }

    // Network errors
    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('offline')) {
      return 'No internet connection. Your action will sync when you\'re back online.';
    }

    // Timeout errors
    if (errorString.contains('timeout') || errorString.contains('deadline')) {
      return 'Request took too long. Please check your connection and try again.';
    }

    // Fallback
    return defaultMessage ??
        'Unable to complete. Please try again or contact support.';
  }

  /// Check if error is recoverable (user can retry)
  static bool isRecoverable(String errorCode) {
    switch (errorCode) {
      case 'deadline-exceeded':
      case 'unavailable':
      case 'resource-exhausted':
      case 'unknown':
      case 'internal':
        return true;

      case 'unauthenticated':
      case 'permission-denied':
      case 'not-found':
      case 'invalid-argument':
      case 'failed-precondition':
      case 'already-exists':
        return false;

      default:
        return true; // Assume recoverable unless known otherwise
    }
  }

  /// Get suggested action for error
  static String? getSuggestedAction(String errorCode) {
    switch (errorCode) {
      case 'unauthenticated':
        return 'Sign in again';

      case 'permission-denied':
        return 'Contact your manager';

      case 'deadline-exceeded':
      case 'unavailable':
        return 'Try again';

      case 'invalid-argument':
        return 'Check GPS signal';

      default:
        return null;
    }
  }
}
