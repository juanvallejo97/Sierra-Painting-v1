import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sierra_painting/core/models/sync_status.dart' as models;
import 'package:sierra_painting/core/widgets/sync_status_chip.dart';

Future<void> _pumpWithMaterial(
  WidgetTester tester, {
  required Widget child,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(child: child),
      ),
    ),
  );
}

void main() {
  group('SyncStatusChip', () {
    testWidgets('renders when status = synced', (tester) async {
      const chipKey = Key('sync-chip-synced');

      await _pumpWithMaterial(
        tester,
        child: const SyncStatusChip(
          key: chipKey,
          status: models.SyncStatus.synced,
        ),
      );

      expect(find.byKey(chipKey), findsOneWidget);
      expect(find.text('Synced'), findsOneWidget);
    });

    testWidgets('renders when status = pending', (tester) async {
      const chipKey = Key('sync-chip-pending');

      await _pumpWithMaterial(
        tester,
        child: const SyncStatusChip(
          key: chipKey,
          status: models.SyncStatus.pending,
        ),
      );

      expect(find.byKey(chipKey), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('renders when status = failed', (tester) async {
      const chipKey = Key('sync-chip-failed');

      await _pumpWithMaterial(
        tester,
        child: const SyncStatusChip(
          key: chipKey,
          status: models.SyncStatus.failed,
        ),
      );

      expect(find.byKey(chipKey), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
    });
  });
}
