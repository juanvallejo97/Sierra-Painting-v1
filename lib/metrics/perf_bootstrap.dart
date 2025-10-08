import 'package:firebase_performance/firebase_performance.dart';

/// Call this once after Firebase.initializeApp().
Future<void> initPerformanceMonitoring() async {
  final perf = FirebasePerformance.instance;
  // Optionally allow runtime toggles if you add settings later:
  await perf.setPerformanceCollectionEnabled(true);
  // Auto HTTP metrics work out of the box for mobile & web.
}
