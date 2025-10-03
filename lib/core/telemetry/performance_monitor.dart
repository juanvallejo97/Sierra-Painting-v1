/// Performance Monitor for Screen Tracking
///
/// PURPOSE:
/// Track screen load times, interaction latency, and performance metrics.
/// Integrates with Firebase Performance Monitoring.
///
/// USAGE:
/// ```dart
/// class MyScreen extends StatefulWidget {
///   @override
///   State<MyScreen> createState() => _MyScreenState();
/// }
///
/// class _MyScreenState extends State<MyScreen> with PerformanceMonitorMixin {
///   @override
///   String get screenName => 'my_screen';
///
///   @override
///   void initState() {
///     super.initState();
///     startScreenTrace();
///   }
///
///   @override
///   void dispose() {
///     stopScreenTrace();
///     super.dispose();
///   }
/// }
/// ```
///
/// METRICS:
/// - Screen render time (time to first meaningful paint)
/// - Interaction latency (button tap to response)
/// - Network request duration
/// - Custom metrics per screen

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'; // ✅ needed for State/StatefulWidget/BuildContext/StatelessWidget

/// Performance trace
class PerformanceTrace {
  final String name;
  final DateTime startTime;
  DateTime? endTime;
  final Map<String, dynamic> attributes;
  final Map<String, num> metrics;

  PerformanceTrace(this.name)
    : startTime = DateTime.now(),
      attributes = {},
      metrics = {};

  /// Stop the trace
  void stop() {
    endTime = DateTime.now();
    _logTrace();
  }

  /// Add an attribute to the trace
  void setAttribute(String key, String value) {
    attributes[key] = value;
  }

  /// Add a metric to the trace
  void setMetric(String key, num value) {
    metrics[key] = value;
  }

  /// Get duration in milliseconds
  int get durationMs {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime).inMilliseconds;
  }

  void _logTrace() {
    if (kDebugMode) {
      debugPrint('[Performance] Trace: $name');
      debugPrint('  Duration: ${durationMs}ms');
      if (attributes.isNotEmpty) {
        debugPrint('  Attributes: $attributes');
      }
      if (metrics.isNotEmpty) {
        debugPrint('  Metrics: $metrics');
      }
    }
    // TODO: Send to Firebase Performance Monitoring
  }
}

/// Performance Monitor Service
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  final Map<String, PerformanceTrace> _activeTraces = {};

  /// Start a custom trace
  PerformanceTrace startTrace(String name) {
    final trace = PerformanceTrace(name);
    _activeTraces[name] = trace;
    return trace;
  }

  /// Stop a trace
  void stopTrace(String name) {
    final trace = _activeTraces[name];
    if (trace != null) {
      trace.stop();
      _activeTraces.remove(name);
    }
  }

  /// Get an active trace
  PerformanceTrace? getTrace(String name) {
    return _activeTraces[name];
  }

  /// Record a network request
  void recordNetworkRequest({
    required String url,
    required String method,
    required int statusCode,
    required int durationMs,
    int? requestSize,
    int? responseSize,
  }) {
    if (kDebugMode) {
      debugPrint('[Performance] Network: $method $url');
      debugPrint('  Status: $statusCode, Duration: ${durationMs}ms');
      if (requestSize != null) {
        debugPrint('  Request size: ${requestSize}B');
      }
      if (responseSize != null) {
        debugPrint('  Response size: ${responseSize}B');
      }
    }
    // TODO: Send to Firebase Performance Monitoring
  }

  /// Record custom metric
  void recordMetric({
    required String name,
    required num value,
    Map<String, String>? attributes,
  }) {
    if (kDebugMode) {
      debugPrint('[Performance] Metric: $name = $value');
      if (attributes != null && attributes.isNotEmpty) {
        debugPrint('  Attributes: $attributes');
      }
    }
    // TODO: Send to Firebase Performance Monitoring
  }
}

/// Mixin for automatic screen performance tracking
mixin PerformanceMonitorMixin<T extends StatefulWidget> on State<T> {
  PerformanceTrace? _screenTrace;

  /// Screen name for tracking (must be overridden)
  String get screenName;

  /// Start screen trace
  void startScreenTrace() {
    final monitor = PerformanceMonitor();
    _screenTrace = monitor.startTrace('screen_$screenName');
    _screenTrace?.setAttribute('screen', screenName);
  }

  /// Stop screen trace
  void stopScreenTrace() {
    _screenTrace?.stop();
    _screenTrace = null;
  }

  /// Record an interaction
  void recordInteraction(String name, int durationMs) {
    final monitor = PerformanceMonitor();
    monitor.recordMetric(
      name: 'interaction_${name}_latency',
      value: durationMs,
      attributes: {'screen': screenName},
    );
  }

  /// Record a custom metric for this screen
  void recordScreenMetric(String name, num value) {
    final monitor = PerformanceMonitor();
    monitor.recordMetric(
      name: '${screenName}_$name',
      value: value,
      attributes: {'screen': screenName},
    );
  }
}

/// Widget that tracks its build time
class PerformanceTrackedWidget extends StatelessWidget {
  final String name;
  final Widget Function(BuildContext) builder;

  const PerformanceTrackedWidget({
    super.key,
    required this.name,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final stopwatch = Stopwatch()..start();
    final built = builder(context);
    stopwatch.stop();

    if (kDebugMode && stopwatch.elapsedMilliseconds > 16) {
      debugPrint(
        '[Performance] Slow build: $name took ${stopwatch.elapsedMilliseconds}ms',
      );
    }

    return built;
  }
}

/// Extension for performance tracking on async operations
extension PerformanceTracking<T> on Future<T> {
  /// Track duration of async operation
  Future<T> tracked(String name) async {
    final monitor = PerformanceMonitor();
    final trace = monitor.startTrace(name);
    try {
      final result = await this;
      trace.stop();
      return result;
    } catch (e) {
      trace.setAttribute('error', e.toString());
      trace.stop();
      rethrow;
    }
  }
}
