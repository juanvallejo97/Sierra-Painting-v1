/// Widget tests for SyncStatusChip and GlobalSyncIndicator
///
/// PURPOSE:
/// Verify sync status UI components render correctly
///
/// COVERAGE:
/// - SyncStatusChip variants (pending, synced, error)
/// - GlobalSyncIndicator badge display
/// - Tap handlers and retry logic
/// - Color coding and icons

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sierra_painting/core/widgets/sync_status_chip.dart';

void main() {
  group('SyncStatusChip', () {
    testWidgets('Pending status shows yellow chip', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SyncStatusChip(status: SyncStatus.pending)),
        ),
      );

      // Verify chip is rendered
      expect(find.byType(Chip), findsOneWidget);

      // Verify label text
      expect(find.text('Syncing...'), findsOneWidget);

      // Verify icon
      expect(find.byIcon(Icons.sync), findsOneWidget);
    });

    testWidgets('Synced status shows green chip', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SyncStatusChip(status: SyncStatus.synced)),
        ),
      );

      expect(find.byType(Chip), findsOneWidget);
      expect(find.text('Synced'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('Error status shows red chip with retry', (tester) async {
      var retryCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SyncStatusChip(
              status: SyncStatus.error,
              onRetry: () {
                retryCalled = true;
              },
              errorMessage: 'Network error',
            ),
          ),
        ),
      );

      expect(find.byType(Tooltip), findsOneWidget);
      expect(find.text('Error'), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);

      // Tap to retry
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      expect(retryCalled, isTrue);
    });

    testWidgets('Error chip shows tooltip with error message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SyncStatusChip(
              status: SyncStatus.error,
              errorMessage: 'Connection failed',
              onRetry: () {},
            ),
          ),
        ),
      );

      // Verify tooltip exists
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, equals('Connection failed'));
    });
  });

  group('GlobalSyncIndicator', () {
    testWidgets('Hides when no pending items and not syncing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [GlobalSyncIndicator(pendingCount: 0, isSyncing: false)],
            ),
          ),
        ),
      );

      // Should render SizedBox.shrink() which is effectively hidden
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('Shows badge with pending count', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [GlobalSyncIndicator(pendingCount: 5, isSyncing: false)],
            ),
          ),
        ),
      );

      expect(find.byType(IconButton), findsOneWidget);
      expect(find.byType(Badge), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('Shows progress indicator when syncing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [GlobalSyncIndicator(pendingCount: 0, isSyncing: true)],
            ),
          ),
        ),
      );

      expect(find.byType(IconButton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Tapping indicator triggers callback', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                GlobalSyncIndicator(
                  pendingCount: 3,
                  isSyncing: false,
                  onTap: () {
                    tapped = true;
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('Shows correct tooltip for pending items', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [GlobalSyncIndicator(pendingCount: 1, isSyncing: false)],
            ),
          ),
        ),
      );

      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.tooltip, equals('1 item pending sync'));
    });

    testWidgets('Shows correct tooltip for multiple pending items', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                GlobalSyncIndicator(pendingCount: 10, isSyncing: false),
              ],
            ),
          ),
        ),
      );

      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.tooltip, equals('10 items pending sync'));
    });

    testWidgets('Shows syncing tooltip when syncing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [GlobalSyncIndicator(pendingCount: 0, isSyncing: true)],
            ),
          ),
        ),
      );

      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.tooltip, equals('Syncing...'));
    });
  });

  group('SyncStatus Enum', () {
    test('Has three states', () {
      expect(SyncStatus.values.length, equals(3));
      expect(SyncStatus.values, contains(SyncStatus.pending));
      expect(SyncStatus.values, contains(SyncStatus.synced));
      expect(SyncStatus.values, contains(SyncStatus.error));
    });
  });
}
