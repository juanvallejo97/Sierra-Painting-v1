import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sierra_painting/app/app.dart';
import 'package:sierra_painting/core/providers/auth_provider.dart';

class _FakeUser implements User {
  final String _email;
  _FakeUser(this._email);

  @override
  String? get email => _email;

  // The rest of the User interface is not needed for this test — stub minimal values.
  @override
  // ignore: no-empty-block
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('unauthenticated users are redirected to /login', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authStateProvider.overrideWithValue(const AsyncValue.data(null))],
        child: const SierraPaintingApp(),
      ),
    );

    await tester.pumpAndSettle();

    // LoginScreen contains a Sign In button
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('authenticated users are redirected away from /login to /timeclock', (tester) async {
    final fakeUser = _FakeUser('user@domain.com');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authStateProvider.overrideWithValue(AsyncValue.data(fakeUser))],
        child: const SierraPaintingApp(),
      ),
    );

    await tester.pumpAndSettle();

  // Timeclock screen's body contains a welcome text; assert it's present.
  expect(find.byKey(const Key('welcomeText')), findsOneWidget);
  });
}
