/// Logger Service
///
/// PURPOSE:
/// Simple logging service for debugging and error tracking.
/// This is a minimal implementation for development.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Simple logger service
class LoggerService {
  /// Log an informational message
  void log(String message) {
    print('[INFO] $message');
  }

  /// Log an info message
  void info(String message, {Map<String, dynamic>? data}) {
    print('[INFO] $message');
    if (data != null) {
      print('[INFO] Data: $data');
    }
  }

  /// Log an error message
  void error(String message, {dynamic error, StackTrace? stackTrace}) {
    print('[ERROR] $message');
    if (error != null) {
      print('[ERROR] Details: $error');
    }
    if (stackTrace != null) {
      print('[ERROR] Stack trace: $stackTrace');
    }
  }

  /// Log a warning message
  void warning(String message, {Map<String, dynamic>? data}) {
    print('[WARNING] $message');
    if (data != null) {
      print('[WARNING] Data: $data');
    }
  }

  /// Log a debug message
  void debug(String message, {Map<String, dynamic>? data}) {
    print('[DEBUG] $message');
    if (data != null) {
      print('[DEBUG] Data: $data');
    }
  }
}

/// Provider for LoggerService
final loggerServiceProvider = Provider<LoggerService>((ref) {
  return LoggerService();
});
