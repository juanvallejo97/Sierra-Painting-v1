import 'package:firebase_performance/firebase_performance.dart';

// Recognize test mode via dart-define set by our test runner.
const bool kFlutterTestMode = bool.fromEnvironment(
  'FLUTTER_TEST',
  defaultValue: false,
);

Future<T> trace<T>(String name, Future<T> Function() run) async {
  // no-op in tests
  if (kFlutterTestMode) return await run();
  final trace = FirebasePerformance.instance.newTrace(name);
  await trace.start();
  try {
    return await run();
  } finally {
    await trace.stop();
  }
}
