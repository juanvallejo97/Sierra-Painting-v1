/// Error Feedback System
///
/// PURPOSE:
/// - Rate-limited error messages (prevent alert storms)
/// - Deduplicate identical errors
/// - User-friendly error copy
/// - Semantic error types for better UX

library error_feedback;

import 'dart:async';
import 'package:flutter/material.dart';

// ============================================================================
// ERROR SEVERITY
// ============================================================================

enum ErrorSeverity {
  info,     // Blue - informational
  warning,  // Amber - needs attention
  error,    // Red - something failed
  success,  // Green - operation succeeded
}

// ============================================================================
// ERROR FEEDBACK MANAGER
// ============================================================================

class ErrorFeedbackManager {
  ErrorFeedbackManager._();
  static final instance = ErrorFeedbackManager._();

  // Rate limiting: max 3 errors per minute
  static const _maxErrorsPerMinute = 3;
  static const _rateLimitWindow = Duration(minutes: 1);

  final List<DateTime> _errorTimestamps = [];
  final Set<String> _recentErrors = {};
  Timer? _cleanupTimer;

  /// Show error feedback to user
  void showError({
    required BuildContext context,
    required String message,
    ErrorSeverity severity = ErrorSeverity.error,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    // Check rate limit
    if (!_checkRateLimit()) {
      debugPrint('ErrorFeedback: Rate limit exceeded, suppressing message');
      return;
    }

    // Check for duplicate (within last 10 seconds)
    if (_isDuplicate(message)) {
      debugPrint('ErrorFeedback: Duplicate message suppressed');
      return;
    }

    // Record this error
    _recordError(message);

    // Show appropriate feedback based on severity
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _getIconForSeverity(severity),
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: _getColorForSeverity(severity),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        action: onAction != null
            ? SnackBarAction(
                label: actionLabel ?? 'RETRY',
                textColor: Colors.white,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }

  /// Show success message
  void showSuccess({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    showError(
      context: context,
      message: message,
      severity: ErrorSeverity.success,
      duration: duration,
    );
  }

  /// Show warning message
  void showWarning({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 4),
  }) {
    showError(
      context: context,
      message: message,
      severity: ErrorSeverity.warning,
      duration: duration,
    );
  }

  /// Show info message
  void showInfo({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    showError(
      context: context,
      message: message,
      severity: ErrorSeverity.info,
      duration: duration,
    );
  }

  /// Check if we're within rate limit
  bool _checkRateLimit() {
    final now = DateTime.now();
    final cutoff = now.subtract(_rateLimitWindow);

    // Remove old timestamps
    _errorTimestamps.removeWhere((timestamp) => timestamp.isBefore(cutoff));

    // Check if we're at limit
    if (_errorTimestamps.length >= _maxErrorsPerMinute) {
      return false;
    }

    return true;
  }

  /// Check if this message is a recent duplicate
  bool _isDuplicate(String message) {
    return _recentErrors.contains(message);
  }

  /// Record an error for deduplication
  void _recordError(String message) {
    _errorTimestamps.add(DateTime.now());
    _recentErrors.add(message);

    // Schedule cleanup of old errors after 10 seconds
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer(const Duration(seconds: 10), () {
      _recentErrors.clear();
    });
  }

  /// Get icon for severity level
  IconData _getIconForSeverity(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.info:
        return Icons.info_outline;
      case ErrorSeverity.warning:
        return Icons.warning_amber;
      case ErrorSeverity.error:
        return Icons.error_outline;
      case ErrorSeverity.success:
        return Icons.check_circle_outline;
    }
  }

  /// Get color for severity level
  Color _getColorForSeverity(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.info:
        return Colors.blue.shade700;
      case ErrorSeverity.warning:
        return Colors.amber.shade700;
      case ErrorSeverity.error:
        return Colors.red.shade700;
      case ErrorSeverity.success:
        return Colors.green.shade700;
    }
  }

  /// Dispose resources
  void dispose() {
    _cleanupTimer?.cancel();
  }
}

// ============================================================================
// CONVENIENCE EXTENSION
// ============================================================================

extension ErrorFeedbackExtension on BuildContext {
  /// Show error message
  void showError(String message, {VoidCallback? onRetry}) {
    ErrorFeedbackManager.instance.showError(
      context: this,
      message: message,
      onAction: onRetry,
    );
  }

  /// Show success message
  void showSuccess(String message) {
    ErrorFeedbackManager.instance.showSuccess(
      context: this,
      message: message,
    );
  }

  /// Show warning message
  void showWarning(String message) {
    ErrorFeedbackManager.instance.showWarning(
      context: this,
      message: message,
    );
  }

  /// Show info message
  void showInfo(String message) {
    ErrorFeedbackManager.instance.showInfo(
      context: this,
      message: message,
    );
  }
}
