import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sierra_painting/features/admin/presentation/admin_home_screen.dart';
import 'package:sierra_painting/features/admin/presentation/providers/admin_review_providers.dart';

void main() {
  group('AdminHomeScreen smoke tests', () {
    testWidgets('renders with loading state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AdminHomeScreen(),
          ),
        ),
      );
      await tester.pump();

      // Screen should render without crashing
      expect(find.text('Admin · Dashboard'), findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Pending Entries'), findsOneWidget);
      expect(find.text('Outside Geofence (24h)'), findsOneWidget);
    });

    testWidgets('renders stat cards with graceful fallback to 0', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          // exceptionCountsProvider will be in loading state
          // Should gracefully fall back to 0 values
          child: MaterialApp(
            home: AdminHomeScreen(),
          ),
        ),
      );
      await tester.pump();

      // Should show 0 values immediately (no spinner)
      expect(find.text('0'), findsWidgets); // Multiple stat cards show 0
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('renders admin menu button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AdminHomeScreen(),
          ),
        ),
      );
      await tester.pump();

      // Admin menu button (PopupMenuButton) should be present
      expect(
        find.widgetWithIcon(PopupMenuButton<String>, Icons.menu),
        findsOneWidget,
      );
    });

    testWidgets('renders quick action buttons', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AdminHomeScreen(),
          ),
        ),
      );
      await tester.pump();

      // Quick action buttons should be present
      expect(find.text('Review Entries'), findsOneWidget);
      expect(find.text('Refresh Admin Token'), findsOneWidget);
    });

    testWidgets('renders with mocked stat data', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exceptionCountsProvider.overrideWith(
              (ref) => Future.value({
                'totalPending': 5,
                'outsideGeofence': 3,
              }),
            ),
          ],
          child: MaterialApp(
            home: AdminHomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show mocked values
      expect(find.text('5'), findsOneWidget); // totalPending
      expect(find.text('3'), findsOneWidget); // outsideGeofence
    });
  });
}
