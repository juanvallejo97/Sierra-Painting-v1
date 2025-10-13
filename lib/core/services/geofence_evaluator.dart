/// Geofence Evaluator Service
///
/// PURPOSE:
/// Evaluates if worker location is within job site geofence.
/// Implements adaptive radius, grace windows, and supervisor overrides.
///
/// FEATURES:
/// - Adaptive geofence radius (urban/suburban/rural)
/// - Grace window for edge cases
/// - Supervisor override workflow
/// - Debounced alerts (avoid notification spam)
/// - Multi-signal verification
/// - Historical geofence tracking
///
/// PRODUCTION REQUIREMENTS (per coach notes):
/// - Urban: 75-100m radius
/// - Suburban: 150m radius
/// - Rural: 250m radius
/// - Grace window before marking violation
/// - Supervisor can override geofence requirement
/// - Debounce alerts to avoid spam
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/services/location_service.dart';
import 'package:sierra_painting/features/jobs/domain/job.dart';

/// Geofence evaluation result
enum GeofenceStatus {
  /// Inside geofence
  inside,

  /// Outside geofence, within grace window
  outsideGrace,

  /// Outside geofence, violation
  outsideViolation,

  /// Supervisor override approved
  overrideApproved,

  /// Cannot determine (poor signal)
  unknown;

  bool get isValid =>
      this == GeofenceStatus.inside || this == GeofenceStatus.overrideApproved;
  bool get isViolation => this == GeofenceStatus.outsideViolation;
  bool get needsOverride =>
      this == GeofenceStatus.outsideGrace ||
      this == GeofenceStatus.outsideViolation;
}

/// Geofence evaluation result
class GeofenceResult {
  final GeofenceStatus status;
  final double distanceMeters;
  final double radiusMeters;
  final bool withinGraceWindow;
  final DateTime timestamp;

  // Override information
  final String? overrideBy; // User ID who approved override
  final String? overrideReason;
  final DateTime? overrideAt;

  GeofenceResult({
    required this.status,
    required this.distanceMeters,
    required this.radiusMeters,
    this.withinGraceWindow = false,
    required this.timestamp,
    this.overrideBy,
    this.overrideReason,
    this.overrideAt,
  });

  /// Check if location is acceptable for clock-in/out
  bool get isAcceptable => status.isValid || withinGraceWindow;

  /// User-friendly status message
  String get statusMessage {
    switch (status) {
      case GeofenceStatus.inside:
        return 'Location verified';
      case GeofenceStatus.outsideGrace:
        return 'Outside job site (${distanceMeters.toStringAsFixed(0)}m away). Request supervisor override?';
      case GeofenceStatus.outsideViolation:
        return 'Location too far from job site (${distanceMeters.toStringAsFixed(0)}m away)';
      case GeofenceStatus.overrideApproved:
        return 'Supervisor override approved';
      case GeofenceStatus.unknown:
        return 'Unable to verify location (poor signal)';
    }
  }

  /// Create copy with override approval
  GeofenceResult withOverride({
    required String overrideBy,
    required String overrideReason,
  }) {
    return GeofenceResult(
      status: GeofenceStatus.overrideApproved,
      distanceMeters: distanceMeters,
      radiusMeters: radiusMeters,
      withinGraceWindow: false,
      timestamp: timestamp,
      overrideBy: overrideBy,
      overrideReason: overrideReason,
      overrideAt: DateTime.now(),
    );
  }
}

/// Supervisor override request
class GeofenceOverrideRequest {
  final String workerId;
  final String jobId;
  final String supervisorId;
  final String reason;
  final LocationResult workerLocation;
  final DateTime requestedAt;

  GeofenceOverrideRequest({
    required this.workerId,
    required this.jobId,
    required this.supervisorId,
    required this.reason,
    required this.workerLocation,
    required this.requestedAt,
  });
}

/// Abstract geofence evaluator interface
abstract class GeofenceEvaluator {
  /// Evaluate if location is within job geofence
  ///
  /// Parameters:
  /// - location: Current worker location
  /// - job: Job with geofence definition
  /// - graceWindowMinutes: Grace period before marking violation (default: 5)
  /// - requireMultiSignal: Require 2/3 signal verification (default: true)
  Future<GeofenceResult> evaluate({
    required LocationResult location,
    required Job job,
    int graceWindowMinutes = 5,
    bool requireMultiSignal = true,
  });

  /// Request supervisor override for out-of-geofence clock-in
  ///
  /// Sends notification to supervisor for approval
  /// Returns pending override request ID
  Future<String> requestOverride({required GeofenceOverrideRequest request});

  /// Approve supervisor override
  ///
  /// Called by supervisor to approve worker's geofence exception
  Future<void> approveOverride({
    required String overrideRequestId,
    required String supervisorId,
  });

  /// Deny supervisor override
  Future<void> denyOverride({
    required String overrideRequestId,
    required String supervisorId,
    String? reason,
  });

  /// Get pending override requests for supervisor
  Future<List<GeofenceOverrideRequest>> getPendingOverrides({
    required String supervisorId,
  });

  /// Check if alert should be shown (debounced)
  ///
  /// Prevents alert spam by checking last alert time
  /// Returns true if enough time has passed since last alert
  Future<bool> shouldShowAlert({
    required String workerId,
    required String jobId,
    Duration cooldownPeriod = const Duration(minutes: 15),
  });

  /// Record alert shown (for debouncing)
  Future<void> recordAlertShown({
    required String workerId,
    required String jobId,
  });

  /// Calculate adaptive radius based on job environment
  ///
  /// Returns recommended radius in meters:
  /// - Urban: 75-100m
  /// - Suburban: 150m
  /// - Rural: 250m
  double getAdaptiveRadius({
    required JobEnvironment environment,
    double? customRadius,
  }) {
    if (customRadius != null) return customRadius;

    switch (environment) {
      case JobEnvironment.urban:
        return 100.0; // 100m for urban (tighter)
      case JobEnvironment.suburban:
        return 150.0; // 150m for suburban
      case JobEnvironment.rural:
        return 250.0; // 250m for rural (wider)
    }
  }

  /// Get historical geofence evaluations for a time entry
  ///
  /// Used for audit trail and dispute resolution
  Future<List<GeofenceResult>> getHistoricalEvaluations({
    required String timeEntryId,
  });

  /// Store geofence evaluation for audit trail
  Future<void> storeEvaluation({
    required String timeEntryId,
    required GeofenceResult result,
  });
}

/// Geofence evaluator exceptions
class GeofenceException implements Exception {
  final String message;
  final GeofenceExceptionType type;

  GeofenceException(this.message, this.type);

  @override
  String toString() => 'GeofenceException: $message';
}

/// Exception types
enum GeofenceExceptionType {
  /// Location accuracy too low for geofence check
  insufficientAccuracy,

  /// Multi-signal requirement not met
  insufficientSignals,

  /// Override request not found
  overrideNotFound,

  /// Unauthorized to approve override
  unauthorized,

  /// Unknown error
  unknown,
}

/// Provider for geofence evaluator
/// Implementation will be provided by concrete class
final geofenceEvaluatorProvider = Provider<GeofenceEvaluator>((ref) {
  throw UnimplementedError(
    'GeofenceEvaluator provider must be overridden with concrete implementation',
  );
});
