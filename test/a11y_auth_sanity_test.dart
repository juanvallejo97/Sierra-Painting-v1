import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/test_harness.dart'; // adjust to your harness path

const sizes = <(double w, double scale)>[
  (1024, 1.15),
  (1024, 1.3),
  (768, 1.0),
  (768, 1.15),
  (768, 1.3),
  (480, 1.0),
  (480, 1.15),
  (390, 1.0),
  (390, 1.3),
  (360, 1.0),
  (360, 1.15),
];

Finder get emailF => find.byKey(const ValueKey('auth.email'));
Finder get passF => find.byKey(const ValueKey('auth.password'));
Finder get signIn => find.byKey(const ValueKey('auth.signIn'));

Future<void> bringIntoView(WidgetTester tester, Finder f) async {
  if (!tester.any(f)) return; // let expect give a good message later
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

void main() {
  for (final (w, scale) in sizes) {
    testWidgets('auth renders (w=$w, scale=$scale) no exceptions', (
      tester,
    ) async {
      await setDeviceSize(
        tester,
        Size(w, 800),
        textScale: scale,
      ); // helper in your harness
      await pumpLogin(tester, authenticated: false); // helper in your harness
      await tester.pumpAndSettle();

      expect(
        emailF,
        findsOneWidget,
        reason: 'Email field should be visible at width $w',
      );
      expect(
        passF,
        findsOneWidget,
        reason: 'Password field should be visible at width $w',
      );
      expect(
        signIn,
        findsOneWidget,
        reason: 'Sign in button should be visible at width $w',
      );

      await bringIntoView(tester, emailF);
      await bringIntoView(tester, passF);
      await bringIntoView(tester, signIn);

      // Optional quick a11y assertion:
      final semantics = tester.getSemantics(signIn);
      expect(
        semantics.label.isNotEmpty,
        true,
        reason: 'Sign in button needs a label',
      );
    });
  }
}
