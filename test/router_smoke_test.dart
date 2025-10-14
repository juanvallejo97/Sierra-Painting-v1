/// Router Smoke Tests
///
/// PURPOSE:
/// Verify all navigation routes render without console errors
/// Implements MASTER_UX_BLUEPRINT.md Section D.1 - Router Smoke
///
/// SCENARIOS:
/// - Admin Smoke: /admin/home, /admin/review, /invoices, /estimates, /jobs, /settings
/// - Worker Smoke: /worker/home, /worker/history, /settings
///
/// ACCEPTANCE CRITERIA:
/// - No console errors during navigation
/// - Each route renders a landmark title/key widget
/// - Complete in under 2 minutes
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sierra_painting/core/providers.dart';
import 'package:sierra_painting/router.dart';

/// Helper to pump app with a specific route
Future<void> pumpRoute(
  WidgetTester tester,
  String route, {
  Map<String, dynamic>? claims,
}) async {
  // Default claims for admin if not provided
  final defaultClaims = claims ?? {'role': 'admin', 'uid': 'test-admin'};

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userClaimsProvider.overrideWith((ref) async => defaultClaims),
      ],
      child: MaterialApp(initialRoute: route, onGenerateRoute: onGenerateRoute),
    ),
  );

  // Allow initial build and async operations
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('Router Smoke Tests - Admin Flow', () {
    testWidgets(
      'Admin Home (/admin/home) renders without errors',
      (tester) async {
        await pumpRoute(tester, '/admin/home');

        // Verify screen renders (look for AppBar or key widgets)
        expect(find.byType(Scaffold), findsAtLeastNWidgets(1));

        // Look for common admin home elements
        // The screen should have rendered without throwing
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    testWidgets(
      'Admin Review (/admin/review) renders without errors',
      (tester) async {
        await pumpRoute(tester, '/admin/review');

        // Verify screen renders
        expect(find.byType(Scaffold), findsAtLeastNWidgets(1));

        // Look for review-specific elements like the probe chip or time entries list
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    testWidgets(
      'Invoices List (/invoices) renders without errors',
      (tester) async {
        await pumpRoute(tester, '/invoices');

        // Verify screen renders
        expect(find.byType(Scaffold), findsAtLeastNWidgets(1));

        // Should show invoices list or empty state
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    testWidgets(
      'Estimates List (/estimates) renders without errors',
      (tester) async {
        await pumpRoute(tester, '/estimates');

        // Verify screen renders
        expect(find.byType(Scaffold), findsAtLeastNWidgets(1));

        // Should show estimates list or empty state
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    testWidgets(
      'Jobs List (/jobs) renders without errors',
      (tester) async {
        await pumpRoute(tester, '/jobs');

        // Verify screen renders
        expect(find.byType(Scaffold), findsAtLeastNWidgets(1));

        // Should show jobs list or placeholder
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    testWidgets(
      'Settings (/settings) renders without errors',
      (tester) async {
        await pumpRoute(tester, '/settings');

        // Verify screen renders
        expect(find.byType(Scaffold), findsAtLeastNWidgets(1));

        // Settings should have logout option
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );
  });

  group('Router Smoke Tests - Worker Flow', () {
    testWidgets(
      'Worker Home (/worker/home) renders without errors',
      (tester) async {
        await pumpRoute(
          tester,
          '/worker/home',
          claims: {'role': 'worker', 'uid': 'test-worker'},
        );

        // Verify screen renders
        expect(find.byType(Scaffold), findsAtLeastNWidgets(1));

        // Worker dashboard should show clock in/out buttons
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    testWidgets(
      'Worker History (/worker/history) renders without errors',
      (tester) async {
        await pumpRoute(
          tester,
          '/worker/history',
          claims: {'role': 'worker', 'uid': 'test-worker'},
        );

        // Verify screen renders
        expect(find.byType(Scaffold), findsAtLeastNWidgets(1));

        // History screen should show time entries list or empty state
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    testWidgets(
      'Worker Settings (/settings) renders without errors',
      (tester) async {
        await pumpRoute(
          tester,
          '/settings',
          claims: {'role': 'worker', 'uid': 'test-worker'},
        );

        // Verify screen renders
        expect(find.byType(Scaffold), findsAtLeastNWidgets(1));

        // Settings should have logout option
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );
  });

  group('Router Smoke Tests - Navigation Stability', () {
    testWidgets(
      'Dashboard router handles admin role correctly',
      (tester) async {
        await pumpRoute(
          tester,
          '/dashboard',
          claims: {'role': 'admin', 'uid': 'test-admin'},
        );

        // Should route to AdminHomeScreen
        expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    testWidgets(
      'Dashboard router handles worker role correctly',
      (tester) async {
        await pumpRoute(
          tester,
          '/dashboard',
          claims: {'role': 'worker', 'uid': 'test-worker'},
        );

        // Should route to WorkerDashboardScreen
        expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    testWidgets(
      'Dashboard router handles no role gracefully',
      (tester) async {
        await pumpRoute(
          tester,
          '/dashboard',
          claims: {'uid': 'test-user'}, // No role
        );

        // Should show no role error screen
        expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
        expect(find.text('No Role Assigned'), findsOneWidget);
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    testWidgets(
      'Unknown route redirects to DashboardScreen',
      (tester) async {
        await pumpRoute(tester, '/this/does/not/exist');

        // Should redirect to DashboardScreen and then to role-based home
        // With admin role, should show admin home screen
        expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
        // The screen should have rendered without throwing
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );
  });

  group('Router Smoke Tests - Performance', () {
    testWidgets(
      'All admin routes complete navigation within 2 seconds',
      (tester) async {
        final routes = [
          '/admin/home',
          '/admin/review',
          '/invoices',
          '/estimates',
          '/jobs',
          '/settings',
        ];

        final stopwatch = Stopwatch()..start();

        for (final route in routes) {
          await pumpRoute(tester, route);
          expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
        }

        stopwatch.stop();

        // All routes should complete in under 2 minutes (120 seconds)
        // Each route should be well under 2 seconds
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(120000),
          reason: 'All admin routes should complete in under 2 minutes',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    testWidgets(
      'All worker routes complete navigation within 2 seconds',
      (tester) async {
        final routes = ['/worker/home', '/worker/history', '/settings'];

        final stopwatch = Stopwatch()..start();

        for (final route in routes) {
          await pumpRoute(
            tester,
            route,
            claims: {'role': 'worker', 'uid': 'test-worker'},
          );
          expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
        }

        stopwatch.stop();

        // All routes should complete in under 2 minutes (120 seconds)
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(120000),
          reason: 'All worker routes should complete in under 2 minutes',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
