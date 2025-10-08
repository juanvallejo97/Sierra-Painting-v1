import 'dart:async';

import 'package:firebase_performance/firebase_performance.dart';

// Ensure the performance monitor provides a no-op implementation during tests
const bool kFlutterTest = bool.fromEnvironment(
  'FLUTTER_TEST',
  defaultValue: false,
);

abstract class TraceHandle {
  Future<void> stop();
  void putMetric(String name, int value) {}
}

class _NullTrace implements TraceHandle {
  @override
  Future<void> stop() async {}
  @override
  void putMetric(String name, int value) {}
}

class _PerfTrace implements TraceHandle {
  final Trace _trace;
  _PerfTrace(this._trace);
  @override
  Future<void> stop() => _trace.stop();
  @override
  void putMetric(String name, int value) {
    try {
      _trace.setMetric(name, value);
    } catch (_) {}
  }
}

class PerformanceMonitor {
  PerformanceMonitor._();
  static final PerformanceMonitor instance = PerformanceMonitor._();

  bool get _enabled => !kFlutterTest;

  Future<TraceHandle> start(String name, {Map<String, String>? attrs}) async {
    if (!_enabled) return _NullTrace();
    try {
      final perf = FirebasePerformance.instance;
      final trace = perf.newTrace(name);
      if (attrs != null) {
        attrs.forEach((k, v) {
          try {
            trace.putAttribute(k, v);
          } catch (_) {}
        });
      }
      await trace.start();
      return _PerfTrace(trace);
    } catch (_) {
      return _NullTrace();
    }
  }
}
