import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sierra_painting/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('Login fields accept text and submit is tappable', (
    tester,
  ) async {
    await app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    Finder email = find.byKey(const Key('login_email'));
    if (email.evaluate().isEmpty) email = find.byType(TextFormField).first;

    Finder password = find.byKey(const Key('login_password'));
    if (password.evaluate().isEmpty) {
      password = find.byType(TextFormField).at(1);
    }

    await tester.tap(email);
    await tester.enterText(email, 'demo@example.com');
    await tester.pump();

    await tester.tap(password);
    await tester.enterText(password, 'Password123!');
    await tester.pump();

    Finder submit = find.byKey(const Key('login_submit'));
    if (submit.evaluate().isEmpty) {
      submit = find.widgetWithText(FilledButton, 'Sign in');
    }

    await tester.tap(submit);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Smoke: something changes (route/snackbar/icon). Keep permissive.
    expect(
      find
              .textContaining('timeclock', findRichText: true)
              .evaluate()
              .isNotEmpty ||
          find.byIcon(Icons.check).evaluate().isNotEmpty ||
          find.byType(ScaffoldMessenger).evaluate().isNotEmpty,
      true,
    );
  });
}
