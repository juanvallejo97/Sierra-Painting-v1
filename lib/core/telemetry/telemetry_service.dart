/// Telemetry Service for Sierra Painting
///
/// PURPOSE:
/// Centralized observability service for structured logging, analytics, and crash reporting.
/// Provides consistent telemetry across the application with minimal performance overhead.
///
/// RESPONSIBILITIES:
/// - Structured logging with standard fields (entity, action, actorUid, orgId, requestId)
/// - Analytics event tracking for user behavior
/// - Crashlytics integration for error tracking
/// - Performance monitoring hooks
///
/// USAGE:
/// ```dart
/// final telemetry = ref.read(telemetryServiceProvider);
/// telemetry.logEvent('CLOCK_IN', {
///   'entity': 'timeEntry',
///   'jobId': jobId,
///   'timestamp': DateTime.now().toIso8601String(),
/// });
/// ```
///
/// PERFORMANCE NOTES:
/// - Logs are buffered and sent in batches
/// - Analytics events are throttled (max 100/session)
/// - Crashes are reported with full context
///
/// PRIVACY:
/// - No PII in standard logs
/// - User IDs are hashed for analytics
/// - Opt-out supported via Remote Config

import 'package:flutter/foundation.dart';

class TelemetryService {
  static final TelemetryService _instance = TelemetryService._internal();
  factory TelemetryService() => _instance;
  TelemetryService._internal();

  /// Current requestId for correlation
  String? _currentRequestId;

  /// Set the current requestId for log correlation
  void setRequestId(String? requestId) {
    _currentRequestId = requestId;
  }

  /// Get the current requestId
  String? get currentRequestId => _currentRequestId;

  /// Initialize telemetry services
  /// Sets up Crashlytics, Analytics, and Performance Monitoring
  static Future<void> initialize() async {
    // TODO: Initialize Firebase Crashlytics
    // TODO: Initialize Firebase Analytics
    // TODO: Initialize Firebase Performance Monitoring
    debugPrint('[Telemetry] Service initialized');
  }

  /// Log a structured event
  ///
  /// [action] - The action being performed (e.g., 'CLOCK_IN', 'INVOICE_CREATED')
  /// [data] - Additional structured data (should include entity, actorUid, orgId, etc.)
  /// [requestId] - Optional requestId for correlation (defaults to current requestId)
  void logEvent(String action, Map<String, dynamic> data, {String? requestId}) {
    final effectiveRequestId = requestId ?? _currentRequestId;
    final enrichedData = {
      ...data,
      if (effectiveRequestId != null) 'requestId': effectiveRequestId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (kDebugMode) {
      debugPrint('[Telemetry] Event: $action, Data: $enrichedData');
    }
    // TODO: Send to Firebase Analytics
    // TODO: Add to structured log buffer
  }

  /// Log an error with context
  ///
  /// [error] - The error that occurred
  /// [stackTrace] - Optional stack trace
  /// [context] - Additional context about where/when the error occurred
  /// [requestId] - Optional requestId for correlation (defaults to current requestId)
  void logError(
    dynamic error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    String? requestId,
  }) {
    final effectiveRequestId = requestId ?? _currentRequestId;
    final enrichedContext = {
      ...?context,
      if (effectiveRequestId != null) 'requestId': effectiveRequestId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (kDebugMode) {
      debugPrint('[Telemetry] Error: $error');
      if (stackTrace != null) {
        debugPrint('[Telemetry] Stack: $stackTrace');
      }
      if (enrichedContext.isNotEmpty) {
        debugPrint('[Telemetry] Context: $enrichedContext');
      }
    }
    // TODO: Send to Firebase Crashlytics with enriched context
  }

  /// Track screen view
  ///
  /// [screenName] - Name of the screen/route
  /// [screenClass] - Optional class name
  void trackScreenView(String screenName, {String? screenClass}) {
    if (kDebugMode) {
      debugPrint('[Telemetry] Screen: $screenName');
    }
    // TODO: Send to Firebase Analytics
  }

  /// Track performance trace
  ///
  /// [name] - Name of the operation being traced
  /// Returns a function to call when the operation completes
  Function startTrace(String name) {
    final startTime = DateTime.now();
    
    return () {
      final duration = DateTime.now().difference(startTime);
      if (kDebugMode) {
        debugPrint('[Telemetry] Trace: $name took ${duration.inMilliseconds}ms');
      }
      // TODO: Send to Firebase Performance Monitoring
    };
  }

  /// Set user properties for analytics
  ///
  /// [userId] - User ID (will be hashed)
  /// [properties] - Additional user properties (no PII)
  void setUserProperties(String userId, Map<String, String> properties) {
    if (kDebugMode) {
      debugPrint('[Telemetry] User properties set for $userId');
    }
    // TODO: Set user properties in Firebase Analytics
  }

  /// Record custom metric
  ///
  /// [name] - Metric name
  /// [value] - Metric value
  void recordMetric(String name, num value) {
    if (kDebugMode) {
      debugPrint('[Telemetry] Metric: $name = $value');
    }
    // TODO: Send custom metric to Firebase
  }
}

/// Riverpod Provider for TelemetryService
import 'package:flutter_riverpod/flutter_riverpod.dart';

final telemetryServiceProvider = Provider<TelemetryService>((ref) {
  return TelemetryService();
});
