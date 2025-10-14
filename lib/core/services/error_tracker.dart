/// Error Tracking Service
///
/// Abstracts error/crash reporting with test-safe implementation.
/// In test/web mode, logs to console. In production mobile, uses Crashlytics.
library;

import 'package:flutter/foundation.dart';

abstract class ErrorTracker {
  /// Report non-fatal error with context
  void nonFatal(
    Object error,
    StackTrace? stackTrace, {
    Map<String, dynamic>? context,
  });

  /// Report fatal error (crashes app)
  void fatal(
    Object error,
    StackTrace? stackTrace, {
    Map<String, dynamic>? context,
  });

  /// Set user identifier for error context
  void setUserId(String? userId);

  /// Add custom key-value context
  void setCustomKey(String key, dynamic value);
}

/// Console-based error tracker (test/web safe)
class ConsoleErrorTracker implements ErrorTracker {
  @override
  void nonFatal(
    Object error,
    StackTrace? stackTrace, {
    Map<String, dynamic>? context,
  }) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[ERROR] $error');
      // ignore: avoid_print
      if (context != null) print('[CONTEXT] $context');
      // ignore: avoid_print
      if (stackTrace != null) print(stackTrace);
    }
  }

  @override
  void fatal(
    Object error,
    StackTrace? stackTrace, {
    Map<String, dynamic>? context,
  }) {
    nonFatal(error, stackTrace, context: context);
    // In real impl, would call FlutterError.presentError
  }

  @override
  void setUserId(String? userId) {
    // ignore: avoid_print
    if (kDebugMode) print('[USER_ID] $userId');
  }

  @override
  void setCustomKey(String key, dynamic value) {
    // ignore: avoid_print
    if (kDebugMode) print('[CUSTOM] $key = $value');
  }
}

/// Factory: Returns appropriate tracker based on environment
ErrorTracker buildErrorTracker({bool isUnderTest = false}) {
  // For now, always use console tracker
  // TODO: Add FirebaseCrashlyticsTracker for mobile production
  return ConsoleErrorTracker();
}
