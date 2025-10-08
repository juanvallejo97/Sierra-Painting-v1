import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sierra_painting/router.dart';
import 'firebase_test_setup.dart';

/// Pumps the app at /login. Auth is not overridden here (safe default).
Future<void> pumpLogin(
  WidgetTester tester, {
  bool authenticated = false,
}) async {
  await setupFirebaseForTesting();
  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(
        initialRoute: '/login',
        onGenerateRoute: onGenerateRoute,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
