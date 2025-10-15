/// Logger Service
///
/// PURPOSE:
/// Structured logging service with breadcrumb tracking for debugging and error tracking.
/// Uses the logger package for proper log formatting and level management.
///
/// FEATURES:
/// - Multiple log levels (debug, info, warning, error)
/// - Breadcrumb tracking for navigation and critical flows
/// - Structured data logging
/// - Proper stack trace handling
/// - No raw print statements
library;

import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Breadcrumb for tracking user flow
class Breadcrumb {
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic>? data;
  final String level;

  Breadcrumb({required this.message, required this.level, this.data})
    : timestamp = DateTime.now();

  @override
  String toString() {
    final dataStr = data != null ? ' | Data: $data' : '';
    return '[$level] $timestamp: $message$dataStr';
  }
}

/// Structured logger service with breadcrumb support
class LoggerService {
  final List<Breadcrumb> _breadcrumbs = [];
  static const int maxBreadcrumbs = 100;

  /// Add a breadcrumb
  void addBreadcrumb(
    String message, {
    String level = 'INFO',
    Map<String, dynamic>? data,
  }) {
    _breadcrumbs.add(Breadcrumb(message: message, level: level, data: data));
    if (_breadcrumbs.length > maxBreadcrumbs) {
      _breadcrumbs.removeAt(0);
    }
  }

  /// Get all breadcrumbs
  List<Breadcrumb> get breadcrumbs => List.unmodifiable(_breadcrumbs);

  /// Log an informational message
  void log(String message) {
    _logWithLevel('INFO', message);
    addBreadcrumb(message, level: 'INFO');
  }

  /// Log an info message
  void info(String message, {Map<String, dynamic>? data}) {
    _logWithLevel('INFO', message, data: data);
    addBreadcrumb(message, level: 'INFO', data: data);
  }

  /// Log an error message
  void error(String message, {dynamic error, StackTrace? stackTrace}) {
    _logWithLevel('ERROR', message, error: error, stackTrace: stackTrace);
    addBreadcrumb(
      message,
      level: 'ERROR',
      data: error != null ? {'error': error.toString()} : null,
    );
  }

  /// Log a warning message
  void warning(String message, {Map<String, dynamic>? data}) {
    _logWithLevel('WARNING', message, data: data);
    addBreadcrumb(message, level: 'WARNING', data: data);
  }

  /// Log a debug message
  void debug(String message, {Map<String, dynamic>? data}) {
    if (kDebugMode) {
      _logWithLevel('DEBUG', message, data: data);
      addBreadcrumb(message, level: 'DEBUG', data: data);
    }
  }

  /// Internal logging with proper formatting
  void _logWithLevel(
    String level,
    String message, {
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    // Use dart:developer log instead of print for better debugging
    final buffer = StringBuffer();
    buffer.write('[$level] $message');

    if (data != null && data.isNotEmpty) {
      buffer.write(' | Data: $data');
    }

    if (error != null) {
      buffer.write(' | Error: $error');
    }

    // Log to developer console with proper level
    developer.log(
      buffer.toString(),
      name: 'SierraPainting',
      level: _getLevelInt(level),
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Convert level string to int for developer.log
  int _getLevelInt(String level) {
    switch (level) {
      case 'DEBUG':
        return 500; // Fine level
      case 'INFO':
        return 800; // Info level
      case 'WARNING':
        return 900; // Warning level
      case 'ERROR':
        return 1000; // Severe level
      default:
        return 800;
    }
  }

  /// Clear all breadcrumbs
  void clearBreadcrumbs() {
    _breadcrumbs.clear();
  }

  /// Get breadcrumbs as formatted string (useful for error reports)
  String getBreadcrumbsAsString() {
    return _breadcrumbs.map((b) => b.toString()).join('\n');
  }
}

/// Provider for LoggerService
final loggerServiceProvider = Provider<LoggerService>((ref) {
  return LoggerService();
});
