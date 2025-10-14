import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sierra_painting/features/admin/presentation/admin_review_screen.dart';
import 'package:sierra_painting/features/admin/presentation/providers/admin_review_providers.dart';

void main() {
  group('AdminReviewScreen smoke tests', () {
    testWidgets('renders with loading state', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AdminReviewScreen())),
      );
      await tester.pump();

      // Screen should render without crashing
      expect(find.text('Time Entry Review'), findsOneWidget);
    });

    testWidgets('renders admin menu button in AppBar', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AdminReviewScreen())),
      );
      await tester.pump();

      // Admin menu button (PopupMenuButton) should be present in AppBar
      expect(
        find.widgetWithIcon(PopupMenuButton<String>, Icons.menu),
        findsOneWidget,
      );
    });

    testWidgets('renders refresh button in AppBar', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AdminReviewScreen())),
      );
      await tester.pump();

      // Refresh button should be present
      expect(find.widgetWithIcon(IconButton, Icons.refresh), findsOneWidget);
    });

    testWidgets('renders filter button in AppBar', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AdminReviewScreen())),
      );
      await tester.pump();

      // Filter button should be present
      expect(
        find.widgetWithIcon(IconButton, Icons.filter_list),
        findsOneWidget,
      );
    });

    testWidgets('shows admin menu when tapped', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Mock the providers to avoid Firebase dependencies
            adminPlumbingProbeProvider.overrideWith(
              (ref) => Future.value('OK_test-company'),
            ),
            exceptionCountsProvider.overrideWith(
              (ref) => Future.value({
                'totalPending': 0,
                'outsideGeofence': 0,
                'exceedsMaxHours': 0,
                'disputed': 0,
              }),
            ),
          ],
          child: const MaterialApp(home: AdminReviewScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the menu button
      await tester.tap(
        find.widgetWithIcon(PopupMenuButton<String>, Icons.menu),
      );
      await tester.pumpAndSettle();

      // Menu items should appear
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Time Review'), findsOneWidget);
      expect(find.text('Users (beta)'), findsOneWidget);
      expect(find.text('Reports (beta)'), findsOneWidget);
    });

    testWidgets('renders category tabs', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminPlumbingProbeProvider.overrideWith(
              (ref) => Future.value('OK_test-company'),
            ),
            exceptionCountsProvider.overrideWith(
              (ref) => Future.value({
                'totalPending': 0,
                'outsideGeofence': 0,
                'exceedsMaxHours': 0,
                'disputed': 0,
              }),
            ),
          ],
          child: const MaterialApp(home: AdminReviewScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Category filter chips should be present (may appear multiple times due to stats card)
      expect(find.text('Outside Geofence'), findsWidgets);
      expect(find.text('All Pending'), findsWidgets);
      expect(find.byType(FilterChip), findsNWidgets(6)); // 6 categories
    });

    testWidgets('renders summary stats card with data', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminPlumbingProbeProvider.overrideWith(
              (ref) => Future.value('OK_test-company'),
            ),
            exceptionCountsProvider.overrideWith(
              (ref) => Future.value({
                'totalPending': 10,
                'outsideGeofence': 5,
                'exceedsMaxHours': 3,
                'disputed': 2,
              }),
            ),
          ],
          child: const MaterialApp(home: AdminReviewScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Summary stats should show mocked values
      expect(find.text('10'), findsOneWidget); // Total pending
      expect(find.text('5'), findsOneWidget); // Outside fence
      expect(find.text('3'), findsOneWidget); // >12 hours
      expect(find.text('2'), findsOneWidget); // Disputed
    });
  });
}
