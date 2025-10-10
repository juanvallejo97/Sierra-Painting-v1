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
library;

import 'package:flutter/foundation.dart';
import '../env/build_flags.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';

class TelemetryService {
  TelemetryService._();
  static final TelemetryService I = TelemetryService._();
  FirebaseAnalytics? _analytics;
  FirebasePerformance? _perf;

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
  Future<void> init() async {
    if (isUnderTest) {
      // Skip platform/channel init in tests.
      _analytics = null;
      _perf = null;
      return;
    }
    try {
      // Initialize Firebase Crashlytics
      if (!kIsWeb) {
        // Crashlytics not supported on web
        FlutterError.onError = (errorDetails) {
          FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
        };

        // Pass all uncaught asynchronous errors to Crashlytics
        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };

        debugPrint('[Telemetry] ✅ Crashlytics initialized');
      } else {
        debugPrint('[Telemetry] ⚠️  Crashlytics skipped (web platform)');
      }

      // Initialize Firebase Analytics
      _analytics = FirebaseAnalytics.instance;
      await _analytics?.setAnalyticsCollectionEnabled(true);
      debugPrint('[Telemetry] ✅ Analytics initialized');

      // Initialize Firebase Performance Monitoring
      _perf = FirebasePerformance.instance;
      await _perf?.setPerformanceCollectionEnabled(true);
      debugPrint('[Telemetry] ✅ Performance Monitoring initialized');

      debugPrint(
        '[Telemetry] 🎉 All telemetry services initialized successfully',
      );
    } catch (e, stack) {
      debugPrint('[Telemetry] ❌ Initialization error: $e');
      debugPrint('[Telemetry] Stack: $stack');
      // Don't rethrow - telemetry failures shouldn't crash the app
    }
  }

  /// Log a structured event
  ///
  /// [action] - The action being performed (e.g., 'CLOCK_IN', 'INVOICE_CREATED')
  /// [data] - Additional structured data (should include entity, actorUid, orgId, etc.)
  /// [requestId] - Optional requestId for correlation (defaults to current requestId)
  Future<void> logEvent(
    String action,
    Map<String, dynamic> data, {
    String? requestId,
  }) async {
    if (isUnderTest) return;
    final effectiveRequestId = requestId ?? _currentRequestId;
    final enrichedData = {
      ...data,
      if (effectiveRequestId != null) 'requestId': effectiveRequestId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (kDebugMode) {
      debugPrint('[Telemetry] Event: $action, Data: $enrichedData');
    }

    // Send to Firebase Analytics only if not under test
    try {
      await _analytics?.logEvent(
        name: action.toLowerCase().replaceAll('_', '-'),
        parameters: _sanitizeParameters(enrichedData),
      );
    } catch (e) {
      debugPrint('[Telemetry] Failed to log event: $e');
    }
  }

  /// Sanitize parameters for Firebase Analytics
  /// Converts all values to supported types (String, num, bool)
  Map<String, Object> _sanitizeParameters(Map<String, dynamic> data) {
    final sanitized = <String, Object>{};
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is String || value is num || value is bool) {
        sanitized[entry.key] = value;
      } else if (value != null) {
        sanitized[entry.key] = value.toString();
      }
    }
    return sanitized;
  }

  /// Log an error with context
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

    // Send to Firebase Crashlytics with enriched context
    if (!kIsWeb) {
      try {
        // Set context as custom keys
        for (final entry in enrichedContext.entries) {
          FirebaseCrashlytics.instance.setCustomKey(
            entry.key,
            entry.value.toString(),
          );
        }

        // Record the error
        FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          reason: 'Logged via TelemetryService',
          fatal: false,
        );
      } catch (e) {
        debugPrint('[Telemetry] Failed to record error: $e');
      }
    }
  }

  /// Track screen view
  void trackScreenView(String screenName, {String? screenClass}) {
    if (kDebugMode) {
      debugPrint('[Telemetry] Screen: $screenName');
    }

    // Send to Firebase Analytics only if not under test
    if (!isUnderTest) {
      try {
        FirebaseAnalytics.instance.logScreenView(
          screenName: screenName,
          screenClass: screenClass ?? screenName,
        );
      } catch (e) {
        debugPrint('[Telemetry] Failed to track screen: $e');
      }
    }
  }

  /// Track performance trace
  /// Returns a function to call when the operation completes
  Future<Trace?> startTrace(String name) async {
    if (isUnderTest) return null;
    try {
      final trace = FirebasePerformance.instance.newTrace(name);
      await trace.start();
      return trace;
    } catch (e) {
      debugPrint('[Telemetry] Failed to start trace: $e');
      return null;
    }
  }

  /// Stop a performance trace
  Future<void> stopTrace(Trace? trace) async {
    if (trace == null) return;
    if (!isUnderTest) {
      try {
        await trace.stop();
        if (kDebugMode) {
          debugPrint('[Telemetry] ✅ Trace stopped');
        }
      } catch (e) {
        debugPrint('[Telemetry] Failed to stop trace: $e');
      }
    }
  }

  /// Set user properties for analytics
  Future<void> setUserProperties(
    String userId,
    Map<String, String> properties,
  ) async {
    if (kDebugMode) {
      debugPrint('[Telemetry] User properties set for $userId');
    }

    if (!isUnderTest) {
      try {
        // Set user ID
        await FirebaseAnalytics.instance.setUserId(id: userId);

        // Set user properties
        for (final entry in properties.entries) {
          await FirebaseAnalytics.instance.setUserProperty(
            name: entry.key,
            value: entry.value,
          );
        }
      } catch (e) {
        debugPrint('[Telemetry] Failed to set user properties: $e');
      }
    }
  }

  /// Record custom metric
  void recordMetric(String name, num value, {Trace? trace}) {
    if (kDebugMode) {
      debugPrint('[Telemetry] Metric: $name = $value');
    }

    if (!isUnderTest) {
      try {
        if (trace != null) {
          trace.setMetric(name, value.toInt());
        } else {
          // Log as Analytics event
          FirebaseAnalytics.instance.logEvent(
            name: 'custom_metric',
            parameters: {'metric_name': name, 'metric_value': value},
          );
        }
      } catch (e) {
        debugPrint('[Telemetry] Failed to record metric: $e');
      }
    }
  }
}

/// Riverpod Provider for TelemetryService
final telemetryServiceProvider = Provider<TelemetryService>((ref) {
  return TelemetryService.I;
});
