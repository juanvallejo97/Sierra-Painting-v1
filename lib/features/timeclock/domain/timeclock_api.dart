/// Timeclock API Interface
///
/// PURPOSE:
/// Abstract interface for geofence-enforced time clock operations.
/// Clients call these methods which invoke Cloud Functions for validation.
///
/// ARCHITECTURE:
/// - Client posts clock events → Cloud Function validates → Creates timeEntries
/// - Geofence enforcement happens server-side (Haversine distance calculation)
/// - Idempotency via clientEventId (prevents duplicate entries on retry)
/// - Function-write only pattern for timeEntries collection
///
/// FLOW:
/// 1. clockIn() → calls Cloud Function with location + jobId
/// 2. Function validates: assignment, geofence, no active entry, idempotency
/// 3. Function creates timeEntry with server timestamp
/// 4. Returns timeEntry ID to client
///
/// ERROR HANDLING:
/// - Throws exceptions with user-friendly messages
/// - Geofence violations return clear distance/limit info
/// - Idempotent: returns existing entry if clientEventId already used
library;

/// Clock-in request data
class ClockInRequest {
  final String jobId;
  final double latitude;
  final double longitude;
  final double? accuracy; // GPS accuracy in meters
  final String clientEventId; // For idempotency
  final String deviceId; // For support debugging

  ClockInRequest({
    required this.jobId,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.clientEventId,
    required this.deviceId,
  });

  Map<String, dynamic> toJson() {
    return {
      'jobId': jobId,
      'lat': latitude,
      'lng': longitude,
      if (accuracy != null) 'accuracy': accuracy,
      'clientEventId': clientEventId,
      'deviceId': deviceId,
    };
  }
}

/// Clock-out request data
class ClockOutRequest {
  final String timeEntryId;
  final double latitude;
  final double longitude;
  final double? accuracy; // GPS accuracy in meters
  final String clientEventId; // For idempotency
  final String deviceId; // For support debugging

  ClockOutRequest({
    required this.timeEntryId,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.clientEventId,
    required this.deviceId,
  });

  Map<String, dynamic> toJson() {
    return {
      'timeEntryId': timeEntryId,
      'lat': latitude,
      'lng': longitude,
      if (accuracy != null) 'accuracy': accuracy,
      'clientEventId': clientEventId,
      'deviceId': deviceId,
    };
  }
}

/// Clock-in response from Cloud Function
class ClockInResponse {
  final String id; // Time entry ID
  final bool ok;

  ClockInResponse({
    required this.id,
    required this.ok,
  });

  factory ClockInResponse.fromJson(Map<String, dynamic> json) {
    return ClockInResponse(
      id: json['id'] as String,
      ok: json['ok'] as bool,
    );
  }
}

/// Clock-out response from Cloud Function
class ClockOutResponse {
  final bool ok;
  final String? warning; // Optional warning message (e.g., outside geofence)

  ClockOutResponse({
    required this.ok,
    this.warning,
  });

  factory ClockOutResponse.fromJson(Map<String, dynamic> json) {
    return ClockOutResponse(
      ok: json['ok'] as bool,
      warning: json['warning'] as String?,
    );
  }
}

/// Structured result for clock attempts with user-friendly messaging
class ClockAttemptResult {
  final String? entryId;
  final bool success;
  final String? userMessage; // User-friendly error message
  final String? errorCode; // Error code for programmatic handling

  ClockAttemptResult({
    this.entryId,
    required this.success,
    this.userMessage,
    this.errorCode,
  });

  /// Create success result
  factory ClockAttemptResult.success({
    required String entryId,
    String? message,
  }) {
    return ClockAttemptResult(
      entryId: entryId,
      success: true,
      userMessage: message,
    );
  }

  /// Create failure result
  factory ClockAttemptResult.failure({
    required String errorCode,
    required String userMessage,
  }) {
    return ClockAttemptResult(
      success: false,
      errorCode: errorCode,
      userMessage: userMessage,
    );
  }
}

/// Abstract interface for timeclock Cloud Function calls
///
/// Implementations should use Firebase Callable Functions
/// to invoke the server-side geofence validation.
abstract class TimeclockApi {
  /// Clock in to a job site
  ///
  /// Validates:
  /// - User is assigned to the job
  /// - Location is within geofence (adaptive radius: 75m-250m + accuracy buffer)
  /// - No active time entry exists
  /// - Idempotency via clientEventId
  ///
  /// Returns the created time entry ID.
  ///
  /// Throws:
  /// - 'unauthenticated' if not signed in
  /// - 'invalid-argument' if missing required parameters
  /// - 'not-found' if job doesn't exist
  /// - 'permission-denied' if not assigned to job
  /// - 'failed-precondition' if outside geofence or already clocked in
  Future<ClockInResponse> clockIn(ClockInRequest request);

  /// Clock out from active time entry
  ///
  /// Validates:
  /// - Time entry exists and belongs to user
  /// - Time entry is still active (not already clocked out)
  /// - Location is within geofence
  ///
  /// Returns success status.
  ///
  /// Throws:
  /// - 'unauthenticated' if not signed in
  /// - 'invalid-argument' if missing required parameters
  /// - 'not-found' if time entry or job doesn't exist
  /// - 'permission-denied' if not user's time entry
  /// - 'failed-precondition' if already clocked out or outside geofence
  Future<ClockOutResponse> clockOut(ClockOutRequest request);
}
