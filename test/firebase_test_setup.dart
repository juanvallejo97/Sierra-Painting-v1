import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import '../lib/firebase_options.dart';

Future<void> setupFirebaseForTesting() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (_) {}
}

// ignore_for_file: avoid_relative_lib_imports
// Ensure Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform) is called once and no-ops for web.
