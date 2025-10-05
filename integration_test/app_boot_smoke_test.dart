// Minimal boot smoke test for CI
//
// This is a fast, deterministic health check that verifies the app
// can launch and render its first frame without crashing.
//
// Run with: flutter test integration_test/app_boot_smoke_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sierra_painting/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Boot Smoke Tests', () {
    testWidgets('App launches and renders first frame', (tester) async {
      final startTime = DateTime.now();

      // Launch the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));

      final endTime = DateTime.now();
      final startupMs = endTime.difference(startTime).inMilliseconds;

      // Log startup time
      print('PERFORMANCE_METRIC: app_startup_ms=$startupMs');

      // Verify app has rendered (find MaterialApp or Scaffold)
      final hasMaterialApp = find.byType(MaterialApp).evaluate().isNotEmpty;
      final hasScaffold = find.byType(Scaffold).evaluate().isNotEmpty;

      expect(
        hasMaterialApp || hasScaffold,
        true,
        reason: 'App should have rendered basic UI',
      );

      // Budget: 3000ms for CI environment
      expect(
        startupMs,
        lessThan(3000),
        reason: 'App startup exceeds budget',
      );

      print('✅ App started successfully in ${startupMs}ms');
    });
  });
}
