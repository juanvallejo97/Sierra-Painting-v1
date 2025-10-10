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
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:sierra_painting/core/env/build_flags.dart';

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

  ErrorContext({
    this.userId,
    this.orgId,
    this.requestId,
    this.screen,
    this.action,
    Map<String, dynamic>? extra,
  }) : extra = extra ?? {};

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
    _globalContext = ErrorContext(
      userId: userId,
      orgId: orgId,
      extra: {if (email != null) 'email': email},
    );

    if (kDebugMode) {
      debugPrint(
        '[ErrorTracker] User context set: userId=$userId, orgId=$orgId',
      );
    }

    // Set user context in Firebase Crashlytics
    if (!kIsWeb && !isUnderTest) {
      try {
        if (userId != null) {
          FirebaseCrashlytics.instance.setUserIdentifier(userId);
        }
        if (orgId != null) {
          FirebaseCrashlytics.instance.setCustomKey('orgId', orgId);
        }
        if (email != null) {
          FirebaseCrashlytics.instance.setCustomKey('email', email);
        }
      } catch (e) {
        debugPrint('[ErrorTracker] Failed to set Crashlytics user context: $e');
      }
    }
  }

  /// Clear user context (on logout)
  void clearUserContext() {
    _globalContext = ErrorContext();

    if (kDebugMode) {
      debugPrint('[ErrorTracker] User context cleared');
    }

    // Clear user context in Firebase Crashlytics
    if (!kIsWeb && !isUnderTest) {
      try {
        FirebaseCrashlytics.instance.setUserIdentifier('');
        // Clear custom keys by setting them to empty
        FirebaseCrashlytics.instance.setCustomKey('orgId', '');
        FirebaseCrashlytics.instance.setCustomKey('email', '');
      } catch (e) {
        debugPrint(
          '[ErrorTracker] Failed to clear Crashlytics user context: $e',
        );
      }
    }
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

    // Send to Firebase Crashlytics
    if (!kIsWeb && !isUnderTest) {
      try {
        // Set context as custom keys before recording error
        final contextMap = mergedContext.toMap();
        for (final entry in contextMap.entries) {
          FirebaseCrashlytics.instance.setCustomKey(
            entry.key,
            entry.value.toString(),
          );
        }

        // Record the error
        FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          fatal: fatal,
          reason: 'Severity: ${severity.name}',
        );
      } catch (e) {
        debugPrint('[ErrorTracker] Failed to record error to Crashlytics: $e');
      }
    }
  }

  /// Record a message
  static void recordMessage(
    String message, {
    ErrorSeverity severity = ErrorSeverity.info,
    ErrorContext? context,
  }) {
    final instance = ErrorTracker();
    final mergedContext = _mergeContexts(instance._globalContext, context);

    if (kDebugMode) {
      debugPrint('[ErrorTracker] ${severity.name.toUpperCase()}: $message');
      debugPrint('Context: ${mergedContext.toMap()}');
    }

    // Send to Firebase Crashlytics
    if (!kIsWeb && !isUnderTest) {
      try {
        final contextStr = mergedContext
            .toMap()
            .entries
            .map((e) => '${e.key}=${e.value}')
            .join(', ');
        FirebaseCrashlytics.instance.log(
          '[${severity.name.toUpperCase()}] $message | Context: $contextStr',
        );
      } catch (e) {
        debugPrint('[ErrorTracker] Failed to log message to Crashlytics: $e');
      }
    }
  }

  /// Set a custom key-value pair
  static void setCustomKey(String key, dynamic value) {
    if (kDebugMode) {
      debugPrint('[ErrorTracker] Custom key: $key = $value');
    }

    // Set custom key in Firebase Crashlytics
    if (!kIsWeb && !isUnderTest) {
      try {
        FirebaseCrashlytics.instance.setCustomKey(key, value.toString());
      } catch (e) {
        debugPrint(
          '[ErrorTracker] Failed to set custom key in Crashlytics: $e',
        );
      }
    }
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
