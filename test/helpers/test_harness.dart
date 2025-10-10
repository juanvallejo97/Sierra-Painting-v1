import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sierra_painting/features/auth/view/login_screen.dart';

Future<void> setDeviceSize(
  WidgetTester tester,
  Size size, {
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 2.0;
  tester.binding.platformDispatcher.textScaleFactorTestValue = textScale;
  await tester.pumpAndSettle();
}

Future<void> pumpLogin(
  WidgetTester tester, {
  bool authenticated = false,
}) async {
  await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
  await tester.pumpAndSettle();
}
