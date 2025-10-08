import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sierra_painting/features/timeclock/presentation/timeclock_screen.dart';

void main() {
  testWidgets('TimeclockBody renders welcome without router deps', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: TimeclockBody()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('welcomeText')), findsOneWidget);
  });
}
