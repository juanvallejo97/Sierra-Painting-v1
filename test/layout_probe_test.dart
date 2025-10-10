// Emits basic layout diagnostics in logs to help parity checks.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sierra_painting/router.dart';

void main() {
  testWidgets('layout probe emits widget tree snapshot', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 2.0;

    // Don't call app.main() - it tries to init Firebase even in test mode on CI
    // Instead, directly pump the MaterialApp with router
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(initialRoute: '/', onGenerateRoute: onGenerateRoute),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    debugPrint('WIDGET_COUNT=${tester.allWidgets.length}');
    expect(tester.takeException(), isNull);
  });
}
