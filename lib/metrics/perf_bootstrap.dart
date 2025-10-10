import 'package:firebase_performance/firebase_performance.dart';
import 'package:sierra_painting/core/env/build_flags.dart';

/// Call this once after Firebase.initializeApp().
Future<void> initPerformanceMonitoring() async {
  if (isUnderTest) return;
  final perf = FirebasePerformance.instance;
  // Optionally allow runtime toggles if you add settings later:
  await perf.setPerformanceCollectionEnabled(true);
  // Auto HTTP metrics work out of the box for mobile & web.
}
