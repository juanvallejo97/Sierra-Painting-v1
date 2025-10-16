/// PHASE 2: SKELETON CODE - UX Telemetry & Performance Monitoring
///
/// PURPOSE:
/// - Track user behavior funnels (conversion rates)
/// - Monitor form validation errors
/// - Detect rage-taps and user frustration
/// - Track performance metrics (TTI, FCP, jank)
/// - Alert on UX regressions

library ux_telemetry;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';

// ============================================================================
// DATA STRUCTURES
// ============================================================================

enum FunnelStep {
  invoiceStarted,
  invoiceLineItemAdded,
  invoiceTaxChanged,
  invoiceSent,
  invoicePaid,
  timeEntryClockIn,
  timeEntryClockOut,
  timeEntrySubmitted,
  timeEntryApproved,
  jobCreated,
  jobWorkersAssigned,
  jobStarted,
  jobCompleted,
}

enum PerformanceMetric {
  timeToInteractive,
  firstContentfulPaint,
  scrollJankPercentage,
  frameDropCount,
  memoryUsageMb,
}

enum InteractionEvent {
  rageTap,
  rageScroll,
  formAbandoned,
  buttonRetry,
  helpViewed,
}

class PerformanceThreshold {
  final PerformanceMetric metric;
  final double warningValue;
  final double criticalValue;
  final String unit;

  const PerformanceThreshold({
    required this.metric,
    required this.warningValue,
    required this.criticalValue,
    required this.unit,
  });
}

// ============================================================================
// MAIN UX TELEMETRY CLASS
// ============================================================================

class UXTelemetry {
  UXTelemetry._();

  static final Map<PerformanceMetric, PerformanceThreshold> _thresholds = {};
  static final List<Map<String, dynamic>> _offlineBuffer = [];
  static bool _initialized = false;

  // ============================================================================
  // PUBLIC API - Funnel Tracking
  // ============================================================================

  static void trackFunnel(FunnelStep step, Map<String, dynamic> params) {
    if (!_initialized) {
      debugPrint('UXTelemetry not initialized, skipping funnel tracking');
      return;
    }

    // TODO(Phase 3): Check network connectivity
    final event = {
      'name': 'funnel_${step.name}',
      'timestamp': DateTime.now().toIso8601String(),
      ...params,
    };

    try {
      // TODO(Phase 3): Send to Firebase Analytics
      FirebaseAnalytics.instance.logEvent(
        name: event['name'] as String,
        parameters: event,
      );
    } catch (e) {
      // TODO(Phase 3): Add to offline buffer if network error
      debugPrint('Failed to track funnel: $e');
      _offlineBuffer.add(event);
    }
  }

  static void trackFormError(
    String formName,
    String fieldName,
    String errorType,
  ) {
    if (!_initialized) return;

    // TODO(Phase 3): Track form validation errors
    try {
      FirebaseAnalytics.instance.logEvent(
        name: 'form_validation_error',
        parameters: {
          'form': formName,
          'field': fieldName,
          'error_type': errorType,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // TODO(Phase 3): Check if error rate is spiking
      _checkFormErrorRate(formName, fieldName);
    } catch (e) {
      debugPrint('Failed to track form error: $e');
    }
  }

  static void trackFormCompletion(
    String formName,
    Duration timeSpent,
    int fieldCount,
  ) {
    if (!_initialized) return;

    // TODO(Phase 3): Track successful form submissions
    try {
      FirebaseAnalytics.instance.logEvent(
        name: 'form_completed',
        parameters: {
          'form': formName,
          'duration_seconds': timeSpent.inSeconds,
          'field_count': fieldCount,
        },
      );
    } catch (e) {
      debugPrint('Failed to track form completion: $e');
    }
  }

  // ============================================================================
  // PUBLIC API - User Interaction Events
  // ============================================================================

  static void trackInteraction(
    InteractionEvent event,
    Map<String, dynamic> context,
  ) {
    if (!_initialized) return;

    // TODO(Phase 3): Track user interactions
    try {
      FirebaseAnalytics.instance.logEvent(
        name: 'user_interaction_${event.name}',
        parameters: {
          'event': event.name,
          ...context,
        },
      );

      // TODO(Phase 3): Log frustration events as non-fatal errors
      if (event == InteractionEvent.rageTap ||
          event == InteractionEvent.rageScroll) {
        FirebaseCrashlytics.instance.recordError(
          Exception('User frustration detected: ${event.name}'),
          null,
          fatal: false,
        );
      }
    } catch (e) {
      debugPrint('Failed to track interaction: $e');
    }
  }

  // ============================================================================
  // PUBLIC API - Performance Monitoring
  // ============================================================================

  static void trackPerformance(
    PerformanceMetric metric,
    double value,
    Map<String, dynamic> context,
  ) {
    if (!_initialized) return;

    final threshold = _thresholds[metric];
    if (threshold == null) return;

    // TODO(Phase 3): Log metric to Firebase Performance
    try {
      // TODO(Phase 3): Use Firebase Performance custom traces
      debugPrint('Performance: ${metric.name} = $value ${threshold.unit}');

      // Alert if threshold exceeded
      if (value > threshold.criticalValue) {
        _alertCriticalPerformance(metric, value, context);
      } else if (value > threshold.warningValue) {
        _alertWarningPerformance(metric, value, context);
      }
    } catch (e) {
      debugPrint('Failed to track performance: $e');
    }
  }

  static PerformanceTrace startTrace(String traceName) {
    // TODO(Phase 3): Create actual Firebase Performance trace
    return PerformanceTrace(traceName);
  }

  // ============================================================================
  // PUBLIC API - Initialization & Management
  // ============================================================================

  static Future<void> initialize() async {
    if (_initialized) return;

    // TODO(Phase 3): Load performance thresholds from config
    _loadPerformanceThresholds();

    // TODO(Phase 3): Set up network connectivity listener
    _setupNetworkListener();

    // TODO(Phase 3): Flush any offline events
    await _flushOfflineBuffer();

    _initialized = true;
  }

  static Future<void> flush() async {
    if (_offlineBuffer.isEmpty) return;

    // TODO(Phase 3): Send all buffered events
    for (final event in _offlineBuffer.toList()) {
      try {
        await FirebaseAnalytics.instance.logEvent(
          name: event['name'] as String,
          parameters: event,
        );
        _offlineBuffer.remove(event);
      } catch (e) {
        debugPrint('Failed to flush event: $e');
      }
    }
  }

  // ============================================================================
  // PRIVATE METHODS
  // ============================================================================

  static void _loadPerformanceThresholds() {
    // TODO(Phase 3): Load from remote config or local defaults
    _thresholds[PerformanceMetric.timeToInteractive] = const PerformanceThreshold(
      metric: PerformanceMetric.timeToInteractive,
      warningValue: 2000,
      criticalValue: 3000,
      unit: 'ms',
    );

    _thresholds[PerformanceMetric.firstContentfulPaint] = const PerformanceThreshold(
      metric: PerformanceMetric.firstContentfulPaint,
      warningValue: 1000,
      criticalValue: 1500,
      unit: 'ms',
    );

    _thresholds[PerformanceMetric.scrollJankPercentage] = const PerformanceThreshold(
      metric: PerformanceMetric.scrollJankPercentage,
      warningValue: 5.0,
      criticalValue: 10.0,
      unit: '%',
    );
  }

  static void _checkFormErrorRate(String formName, String fieldName) {
    // TODO(Phase 3): Query recent error count and alert if spiking
    debugPrint('Checking error rate for $formName.$fieldName');
  }

  static void _alertCriticalPerformance(
    PerformanceMetric metric,
    double value,
    Map<String, dynamic> context,
  ) {
    // TODO(Phase 3): Send to Crashlytics as non-fatal error
    FirebaseCrashlytics.instance.recordError(
      Exception('Critical performance regression: ${metric.name} = $value'),
      null,
      fatal: false,
    );
  }

  static void _alertWarningPerformance(
    PerformanceMetric metric,
    double value,
    Map<String, dynamic> context,
  ) {
    // TODO(Phase 3): Log warning
    FirebaseCrashlytics.instance.log(
      'Performance warning: ${metric.name} = $value',
    );
  }

  static Future<void> _setupNetworkListener() async {
    // TODO(Phase 3): Listen to connectivity changes and flush buffer when online
  }

  static Future<void> _flushOfflineBuffer() async {
    // TODO(Phase 3): Send all buffered events on startup if online
    await flush();
  }
}

// ============================================================================
// SUPPORTING CLASSES
// ============================================================================

class PerformanceTrace {
  final String name;
  final DateTime startTime;
  final Map<String, String> attributes = {};

  PerformanceTrace(this.name) : startTime = DateTime.now();

  void setAttribute(String key, String value) {
    // TODO(Phase 3): Add attribute to Firebase Performance trace
    attributes[key] = value;
  }

  void stop() {
    final duration = DateTime.now().difference(startTime);

    // TODO(Phase 3): Stop Firebase Performance trace and record
    debugPrint('Trace $name completed in ${duration.inMilliseconds}ms');
  }
}
