import 'package:flutter/foundation.dart';
import 'dart:ui';

/// Compile-time constant from --dart-define=FLUTTER_TEST=true
const bool _kFlutterTestEnv = bool.hasEnvironment('FLUTTER_TEST');

/// Returns true if running under flutter test
bool get isUnderTest =>
    _kFlutterTestEnv ||
    const bool.fromEnvironment('FLUTTER_TEST', defaultValue: false) ||
    PlatformDispatcher.instance.implicitView == null;
