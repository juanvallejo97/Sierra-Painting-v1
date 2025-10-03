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
///     context: {
///       'userId': user.id,
///       'screen': 'timeclock',
///       'action': 'clock_in',
///     },
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

import 'package:flutter/foundation.dart';

/// Error severity levels
enum ErrorSeverity {
  info,
  warning,
  error,
  fatal,
}

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
  void setUserContext({
    String? userId,
    String? orgId,
    String? email,
  }) {
    _globalContext = ErrorContext(
      userId: userId,
      orgId: orgId,
      extra: {
        if (email != null) 'email': email,
      },
    );
    
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
  static ErrorContext _mergeContexts(
    ErrorContext global,
    ErrorContext? local,
  ) {
    if (local == null) return global;

    return ErrorContext(
      userId: local.userId ?? global.userId,
      orgId: local.orgId ?? global.orgId,
      requestId: local.requestId ?? global.requestId,
      screen: local.screen ?? global.screen,
      action: local.action ?? global.action,
      extra: {
        ...global.extra,
        ...local.extra,
      },
    );
  }

  /// Initialize error tracking
  static Future<void> initialize() async {
    if (kDebugMode) {
      debugPrint('[ErrorTracker] Initializing...');
    }
    
    // TODO: Initialize Firebase Crashlytics
    // await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    
    // Set up Flutter error handler
    FlutterError.onError = (FlutterErrorDetails details) {
      recordError(
        error: details.exception,
        stackTrace: details.stack,
        context: ErrorContext(
          extra: {
            'library': details.library ?? 'unknown',
            'context': details.context?.toString(),
          },
        ),
        fatal: false,
      );
    };

    // Set up platform error handler
    PlatformDispatcher.instance.onError = (error, stack) {
      recordError(
        error: error,
        stackTrace: stack,
        fatal: true,
      );
      return true;
    };

    if (kDebugMode) {
      debugPrint('[ErrorTracker] Initialized successfully');
    }
  }
}

/// Extension for error tracking on Results
import 'package:sierra_painting/core/utils/result.dart';

extension ErrorTrackingResult<T, E> on Result<T, E> {
  /// Track error if Result is failure
  Result<T, E> trackError({
    String? screen,
    String? action,
    ErrorSeverity severity = ErrorSeverity.error,
  }) {
    if (isFailure) {
      ErrorTracker.recordError(
        error: errorOrNull,
        context: ErrorContext(
          screen: screen,
          action: action,
        ),
        severity: severity,
      );
    }
    return this;
  }
}

/// Extension for error tracking on Futures
extension ErrorTrackingFuture<T> on Future<T> {
  /// Catch and track errors
  Future<T> catchError({
    String? screen,
    String? action,
    ErrorSeverity severity = ErrorSeverity.error,
    bool rethrow = true,
  }) async {
    try {
      return await this;
    } catch (error, stackTrace) {
      ErrorTracker.recordError(
        error: error,
        stackTrace: stackTrace,
        context: ErrorContext(
          screen: screen,
          action: action,
        ),
        severity: severity,
      );
      if (rethrow) {
        rethrow;
      }
      throw error;
    }
  }
}
