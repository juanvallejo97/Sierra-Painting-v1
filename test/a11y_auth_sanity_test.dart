import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sierra_painting/main.dart' as app;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // We just make sure auth screens render without overflow/layout exceptions
  // across common phone/tablet widths and text scales.
  final widths = <double>[360, 390, 480, 600, 768, 1024];
  final scales = <double>[1.0, 1.15, 1.3];

  for (final w in widths) {
    for (final s in scales) {
      testWidgets('auth renders (w=$w, scale=$s) no exceptions', (
        tester,
      ) async {
        tester.view.physicalSize = Size(w, 800);
        tester.view.devicePixelRatio = 2.0;

        app.main(); // boots app → login by default
        await tester.pumpAndSettle();

        // Apply a larger text scale and re-pump
        final mq = MediaQuery.of(tester.element(find.byType(MaterialApp)));
        tester.binding.platformDispatcher.textScaleFactorTestValue = s;
        await tester.pumpAndSettle();

        // No overflow banners / exceptions
        expect(tester.takeException(), isNull);

        // Critical controls exist and are tappable
        expect(find.textContaining('Log in', findRichText: true), findsWidgets);
        expect(
          find.textContaining('Create account', findRichText: true),
          findsAtLeastNWidgets(1),
        );

        // Minimum 48px touch target: check a common button (if present)
        final candidates = find.byType(ElevatedButton);
        if (candidates.evaluate().isNotEmpty) {
          final r = tester.getSize(candidates.first);
          expect(r.height >= 48.0, true);
        }

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.binding.platformDispatcher.clearAllTestValues();
        });
      });
    }
  }
}
