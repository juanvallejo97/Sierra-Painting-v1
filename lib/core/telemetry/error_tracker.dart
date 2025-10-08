/// Error Tracking Service
///
/// PURPOSE:
/// Centralized error tracking and reporting with Firebase Crashlytics.
/// Captures errors with context for debugging.
///
/// USAGE:
/// ```dart
/// try {
///   // Some operation
/// } catch (e, stackTrace) {
///   ErrorTracker.recordError(
///     error: e,
///     stackTrace: stackTrace,
///     context: ErrorContext(
///       userId: user.id,
///       screen: 'timeclock',
///       action: 'clock_in',
///     ),
///   );
/// }
/// ```
///
/// FEATURES:
/// - Automatic error context enrichment
/// - RequestId correlation
/// - User context tracking
/// - Non-fatal error reporting
/// - Fatal error reporting with crash
library;

import 'package:flutter/foundation.dart';

/// Error severity levels
enum ErrorSeverity { info, warning, error, fatal }

/// Error context
class ErrorContext {
  final String? userId;
  final String? orgId;
  final String? requestId;
  final String? screen;
  final String? action;
  final Map<String, dynamic> extra;

  ErrorContext({this.userId, this.orgId, this.requestId, this.screen, this.action, Map<String, dynamic>? extra})
    : extra = extra ?? {};

  Map<String, dynamic> toMap() {
    return {
      if (userId != null) 'userId': userId,
      if (orgId != null) 'orgId': orgId,
      if (requestId != null) 'requestId': requestId,
      if (screen != null) 'screen': screen,
      if (action != null) 'action': action,
      ...extra,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}

/// Error Tracker
class ErrorTracker {
  static final ErrorTracker _instance = ErrorTracker._internal();
  factory ErrorTracker() => _instance;
  ErrorTracker._internal();

  /// Current user context
  ErrorContext _globalContext = ErrorContext();

  /// Set global user context
  void setUserContext({String? userId, String? orgId, String? email}) {
    _globalContext = ErrorContext(userId: userId, orgId: orgId, extra: {if (email != null) 'email': email});

    if (kDebugMode) {
      debugPrint('[ErrorTracker] User context set: userId=$userId, orgId=$orgId');
    }
    // TODO: Set user context in Firebase Crashlytics
  }

  /// Clear user context (on logout)
  void clearUserContext() {
    _globalContext = ErrorContext();

    if (kDebugMode) {
      debugPrint('[ErrorTracker] User context cleared');
    }
    // TODO: Clear user context in Firebase Crashlytics
  }

  /// Record a non-fatal error
  static void recordError({
    required dynamic error,
    StackTrace? stackTrace,
    ErrorContext? context,
    ErrorSeverity severity = ErrorSeverity.error,
    bool fatal = false,
  }) {
    final instance = ErrorTracker();
    final mergedContext = _mergeContexts(instance._globalContext, context);

    if (kDebugMode) {
      debugPrint('[ErrorTracker] ${severity.name.toUpperCase()}: $error');
      if (stackTrace != null) {
        debugPrint('Stack trace:\n$stackTrace');
      }
      debugPrint('Context: ${mergedContext.toMap()}');
    }

    // TODO: Send to Firebase Crashlytics
    // if (fatal) {
    //   FirebaseCrashlytics.instance.recordFatalError(error, stackTrace);
    // } else {
    //   FirebaseCrashlytics.instance.recordError(error, stackTrace);
    // }
  }

  /// Record a message
  static void recordMessage(String message, {ErrorSeverity severity = ErrorSeverity.info, ErrorContext? context}) {
    final instance = ErrorTracker();
    final mergedContext = _mergeContexts(instance._globalContext, context);

    if (kDebugMode) {
      debugPrint('[ErrorTracker] ${severity.name.toUpperCase()}: $message');
      debugPrint('Context: ${mergedContext.toMap()}');
    }

    // TODO: Send to Firebase Crashlytics
    // FirebaseCrashlytics.instance.log(message);
  }

  /// Set a custom key-value pair
  static void setCustomKey(String key, dynamic value) {
    if (kDebugMode) {
      debugPrint('[ErrorTracker] Custom key: $key = $value');
    }
    // TODO: Set custom key in Firebase Crashlytics
    // FirebaseCrashlytics.instance.setCustomKey(key, value);
  }

  /// Merge global and local contexts
  static ErrorContext _mergeContexts(ErrorContext global, ErrorContext? local) {
    if (local == null) return global;

    return ErrorContext(
      userId: local.userId ?? global.userId,
      orgId: local.orgId ?? global.orgId,
      requestId: local.requestId ?? global.requestId,
      screen: local.screen ?? global.screen,
      action: local.action ?? global.action,
      extra: {...global.extra, ...local.extra},
    );
  }
}
