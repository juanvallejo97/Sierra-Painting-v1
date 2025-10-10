import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sierra_painting/router.dart';

/// Pumps the app at /login. Auth is not overridden here (safe default).
/// Note: Does NOT initialize Firebase - widget tests should avoid platform channels.
Future<void> pumpLogin(
  WidgetTester tester, {
  bool authenticated = false,
}) async {
  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(
        initialRoute: '/login',
        onGenerateRoute: onGenerateRoute,
      ),
    ),
  );
  // Use pump with duration instead of pumpAndSettle to avoid hanging on animations
  await tester.pump(const Duration(milliseconds: 100));
}
