/// Error Boundary System
///
/// PURPOSE:
/// - Catch and contain Flutter errors at feature level
/// - Prevent cascading failures
/// - Provide fallback UI with retry
/// - Log errors to Crashlytics with consent

library error_boundary;

import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:sierra_painting/core/privacy/consent_manager.dart';
import 'package:sierra_painting/core/privacy/pii_sanitizer.dart';

// ============================================================================
// ERROR BOUNDARY WIDGET
// ============================================================================

class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(Object error, StackTrace? stackTrace)? errorBuilder;
  final VoidCallback? onRetry;
  final String? featureName;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
    this.onRetry,
    this.featureName,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // Note: FlutterError.onError is global, so we capture errors at build time
  }

  void _handleError(Object error, StackTrace stackTrace) {
    setState(() {
      _error = error;
      _stackTrace = stackTrace;
      _hasError = true;
    });

    // Log to Crashlytics if consent granted
    if (ConsentManager.instance.hasConsent(ConsentType.crashlytics)) {
      final sanitizedMessage = PIISanitizer.sanitizeErrorMessage(
        error.toString(),
      );
      final sanitizedStack = PIISanitizer.sanitizeStackTrace(
        stackTrace.toString(),
      );

      FirebaseCrashlytics.instance.recordError(
        Exception(sanitizedMessage),
        StackTrace.fromString(sanitizedStack),
        fatal: false,
        reason: 'Error in ${widget.featureName ?? "unknown feature"}',
      );
    }

    // Log to console in debug mode
    debugPrint('ErrorBoundary caught error in ${widget.featureName}:');
    debugPrint('Error: $error');
    debugPrint('Stack: $stackTrace');
  }

  void _retry() {
    setState(() {
      _error = null;
      _stackTrace = null;
      _hasError = false;
    });

    widget.onRetry?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(_error!, _stackTrace);
      }

      return _DefaultErrorWidget(
        error: _error!,
        stackTrace: _stackTrace,
        onRetry: _retry,
        featureName: widget.featureName,
      );
    }

    // Use a custom error handling builder
    return Builder(
      builder: (context) {
        try {
          return widget.child;
        } catch (error, stackTrace) {
          _handleError(error, stackTrace);
          if (widget.errorBuilder != null) {
            return widget.errorBuilder!(error, stackTrace);
          }
          return _DefaultErrorWidget(
            error: error,
            stackTrace: stackTrace,
            onRetry: _retry,
            featureName: widget.featureName,
          );
        }
      },
    );
  }
}

// ============================================================================
// DEFAULT ERROR WIDGET
// ============================================================================

class _DefaultErrorWidget extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback? onRetry;
  final String? featureName;

  const _DefaultErrorWidget({
    required this.error,
    this.stackTrace,
    this.onRetry,
    this.featureName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            featureName != null
                ? 'Error in $featureName'
                : 'An error occurred while loading this content',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (onRetry != null)
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Go Back'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// FEATURE ERROR BOUNDARY WRAPPER
// ============================================================================

/// Wraps an entire feature with error boundary
class FeatureErrorBoundary extends StatelessWidget {
  final String featureName;
  final Widget child;
  final VoidCallback? onRetry;

  const FeatureErrorBoundary({
    super.key,
    required this.featureName,
    required this.child,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      featureName: featureName,
      onRetry: onRetry,
      child: child,
    );
  }
}
