import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sierra_painting/core/providers.dart';
import 'package:sierra_painting/router.dart';

void main() {
  group('Router Smoke Tests', () {
    testWidgets('Auth routes render without error', (tester) async {
      final routes = ['/login', '/signup', '/forgot'];

      for (final route in routes) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              onGenerateRoute: onGenerateRoute,
              initialRoute: route,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Screen should render without crashing
        expect(find.byType(Scaffold), findsOneWidget);
      }
    });

    testWidgets('Admin routes render without error', (tester) async {
      final routes = ['/admin/home', '/admin/review'];

      for (final route in routes) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              // Mock providers to avoid Firebase dependencies
              userClaimsProvider.overrideWith(
                (ref) => Future.value({'role': 'admin', 'companyId': 'test'}),
              ),
            ],
            child: MaterialApp(
              onGenerateRoute: onGenerateRoute,
              initialRoute: route,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Screen should render without crashing
        expect(find.byType(Scaffold), findsOneWidget);
      }
    });

    testWidgets('Worker routes render without error', (tester) async {
      final routes = ['/worker/home', '/worker/history'];

      for (final route in routes) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              // Mock providers to avoid Firebase dependencies
              userClaimsProvider.overrideWith(
                (ref) => Future.value({'role': 'worker', 'companyId': 'test'}),
              ),
            ],
            child: MaterialApp(
              onGenerateRoute: onGenerateRoute,
              initialRoute: route,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Screen should render without crashing
        expect(find.byType(Scaffold), findsOneWidget);
      }
    });

    testWidgets('Shared routes render without error', (tester) async {
      final routes = ['/jobs', '/invoices', '/estimates', '/settings'];

      for (final route in routes) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              // Mock providers to avoid Firebase dependencies
              userClaimsProvider.overrideWith(
                (ref) => Future.value({'role': 'admin', 'companyId': 'test'}),
              ),
            ],
            child: MaterialApp(
              onGenerateRoute: onGenerateRoute,
              initialRoute: route,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Screen should render without crashing
        expect(find.byType(Scaffold), findsOneWidget);
      }
    });

    testWidgets('Create routes render without error', (tester) async {
      final routes = ['/jobs/create', '/invoices/create', '/estimates/create'];

      for (final route in routes) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              // Mock providers to avoid Firebase dependencies
              userClaimsProvider.overrideWith(
                (ref) => Future.value({'role': 'admin', 'companyId': 'test'}),
              ),
            ],
            child: MaterialApp(
              onGenerateRoute: onGenerateRoute,
              initialRoute: route,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Screen should render without crashing
        expect(find.byType(Scaffold), findsOneWidget);
      }
    });

    testWidgets('Timeclock route renders without error', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Mock providers to avoid Firebase dependencies
            userClaimsProvider.overrideWith(
              (ref) => Future.value({'role': 'worker', 'companyId': 'test'}),
            ),
          ],
          child: const MaterialApp(
            onGenerateRoute: onGenerateRoute,
            initialRoute: '/timeclock',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Screen should render without crashing
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Unknown route falls back to DashboardScreen', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Mock providers to avoid Firebase dependencies
            userClaimsProvider.overrideWith(
              (ref) => Future.value({'role': 'admin', 'companyId': 'test'}),
            ),
          ],
          child: const MaterialApp(
            onGenerateRoute: onGenerateRoute,
            initialRoute: '/unknown-route-12345',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should redirect to DashboardScreen and show admin home
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Dashboard route shows loading state then resolves', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Mock providers with delayed future to test loading state
            userClaimsProvider.overrideWith(
              (ref) => Future.delayed(
                const Duration(milliseconds: 100),
                () => {'role': 'admin', 'companyId': 'test'},
              ),
            ),
          ],
          child: const MaterialApp(
            onGenerateRoute: onGenerateRoute,
            initialRoute: '/dashboard',
          ),
        ),
      );

      // Should show loading indicator initially
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Wait for claims to resolve
      await tester.pumpAndSettle();

      // Should now show the admin home screen
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('Dashboard route handles no role error', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Mock providers with null role
            userClaimsProvider.overrideWith(
              (ref) => Future.value({'companyId': 'test'}),
            ),
          ],
          child: const MaterialApp(
            onGenerateRoute: onGenerateRoute,
            initialRoute: '/dashboard',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show "No Role Assigned" screen
      expect(find.text('No Role Assigned'), findsOneWidget);
      expect(find.text('Refresh Claims'), findsOneWidget);
      expect(find.text('Back to Login'), findsOneWidget);
    });

    testWidgets('Dashboard route handles unknown role', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Mock providers with unknown role
            userClaimsProvider.overrideWith(
              (ref) => Future.value({'role': 'superuser', 'companyId': 'test'}),
            ),
          ],
          child: const MaterialApp(
            onGenerateRoute: onGenerateRoute,
            initialRoute: '/dashboard',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show "Unknown Role" screen
      expect(find.text('Unknown Role'), findsOneWidget);
      expect(find.textContaining('superuser'), findsOneWidget);
      expect(find.text('Back to Login'), findsOneWidget);
    });
  });
}
