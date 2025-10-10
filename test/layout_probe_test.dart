// Emits basic layout diagnostics in logs to help parity checks.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sierra_painting/main.dart' as app;

void main() {
  testWidgets('layout probe emits widget tree snapshot', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 2.0;
    await app.main();
    await tester.pumpAndSettle();
    debugPrint('WIDGET_COUNT=${tester.allWidgets.length}');
    expect(tester.takeException(), isNull);
  });
}
