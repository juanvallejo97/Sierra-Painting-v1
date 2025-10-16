/// PHASE 2: SKELETON CODE - Unified State Components
///
/// PURPOSE:
/// - Consistent empty/error/success states across the app
/// - User-friendly error messages (hide technical details)
/// - Actionable recovery options
/// - Accessible and respects Reduce Motion

library unified_states;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ============================================================================
// EMPTY STATE - No Data Available
// ============================================================================

class EmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? illustrationAsset;
  final VoidCallback? onAction;
  final String? actionLabel;
  final VoidCallback? onHelpTap;

  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.illustrationAsset,
    this.onAction,
    this.actionLabel,
    this.onHelpTap,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (illustrationAsset != null)
              _buildIllustration(context, reduceMotion),
            const SizedBox(height: 24),
            _buildTitle(context),
            if (subtitle != null) _buildSubtitle(context),
            if (onAction != null) _buildActionButton(context),
            if (onHelpTap != null) _buildHelpLink(context),
          ],
        ),
      ),
    );
  }

  Widget _buildIllustration(BuildContext context, bool reduceMotion) {
    // TODO(Phase 3): Use Lottie for animations if feature flag enabled
    return Image.asset(
      illustrationAsset!,
      height: 200,
      semanticLabel: 'No data illustration',
      errorBuilder: (context, error, stackTrace) => const Icon(
        Icons.inbox,
        size: 100,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineSmall,
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        subtitle!,
        style: Theme.of(context).textTheme.bodyMedium,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: FilledButton.icon(
        onPressed: onAction,
        icon: const Icon(Icons.add),
        label: Text(actionLabel ?? 'Get Started'),
      ),
    );
  }

  Widget _buildHelpLink(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: TextButton.icon(
        onPressed: onHelpTap,
        icon: const Icon(Icons.help_outline, size: 16),
        label: const Text('Need help?'),
      ),
    );
  }
}

// ============================================================================
// ERROR STATE - Something Went Wrong
// ============================================================================

class ErrorState extends StatelessWidget {
  final String userMessage;
  final String? technicalError;
  final StackTrace? stackTrace;
  final VoidCallback? onRetry;
  final VoidCallback? onContactSupport;

  const ErrorState({
    super.key,
    required this.userMessage,
    this.technicalError,
    this.stackTrace,
    this.onRetry,
    this.onContactSupport,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Error: $userMessage',
      liveRegion: true,
      child: Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildErrorHeader(context),
              const SizedBox(height: 16),
              _buildErrorMessage(context),
              if (onRetry != null) _buildRetryButton(context),
              if (onContactSupport != null) _buildSupportButton(context),
              if (kDebugMode && technicalError != null)
                _buildTechnicalDetails(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorHeader(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.error_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
        const SizedBox(width: 12),
        Text(
          'Something went wrong',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage(BuildContext context) {
    return Text(
      userMessage,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onErrorContainer,
      ),
    );
  }

  Widget _buildRetryButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: FilledButton.tonal(
        onPressed: onRetry,
        child: const Text('Try Again'),
      ),
    );
  }

  Widget _buildSupportButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextButton.icon(
        onPressed: onContactSupport,
        icon: const Icon(Icons.support_agent),
        label: const Text('Contact Support'),
      ),
    );
  }

  Widget _buildTechnicalDetails(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: ExpansionTile(
        title: const Text('Technical Details'),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[900],
            child: SelectableText(
              '$technicalError\n\n$stackTrace',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: Colors.green[300],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SUCCESS STATE - Action Completed
// ============================================================================

class SuccessState extends StatefulWidget {
  final String message;
  final VoidCallback? onUndo;
  final Duration? autoDismissDuration;
  final VoidCallback? onDismiss;

  const SuccessState({
    super.key,
    required this.message,
    this.onUndo,
    this.autoDismissDuration,
    this.onDismiss,
  });

  @override
  State<SuccessState> createState() => _SuccessStateState();
}

class _SuccessStateState extends State<SuccessState>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _controller.forward();

    if (widget.autoDismissDuration != null) {
      _autoDismissTimer = Timer(widget.autoDismissDuration!, () {
        widget.onDismiss?.call();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Semantics(
      label: 'Success: ${widget.message}',
      liveRegion: true,
      child: Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildCheckmark(reduceMotion),
              const SizedBox(width: 12),
              Expanded(child: _buildMessage(context)),
              if (widget.onUndo != null) _buildUndoButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckmark(bool reduceMotion) {
    if (reduceMotion) {
      return const Icon(Icons.check_circle, color: Colors.green);
    }

    return ScaleTransition(
      scale: CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
      child: const Icon(Icons.check_circle, color: Colors.green),
    );
  }

  Widget _buildMessage(BuildContext context) {
    return Text(
      widget.message,
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }

  Widget _buildUndoButton(BuildContext context) {
    return TextButton(
      onPressed: () {
        _autoDismissTimer?.cancel();
        widget.onUndo?.call();
      },
      child: const Text('UNDO'),
    );
  }
}

// ============================================================================
// LOADING STATE - Operation in Progress
// ============================================================================

class LoadingState extends StatelessWidget {
  final String message;
  final double? progress;
  final VoidCallback? onCancel;

  const LoadingState({
    super.key,
    required this.message,
    this.progress,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading: $message',
      liveRegion: true,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildProgressIndicator(),
                const SizedBox(height: 16),
                _buildMessage(context),
                if (onCancel != null) _buildCancelButton(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    if (progress == null) {
      return const CircularProgressIndicator();
    }
    return CircularProgressIndicator(value: progress);
  }

  Widget _buildMessage(BuildContext context) {
    return Text(
      message,
      style: Theme.of(context).textTheme.bodyMedium,
      textAlign: TextAlign.center,
    );
  }

  Widget _buildCancelButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: TextButton(
        onPressed: onCancel,
        child: const Text('Cancel'),
      ),
    );
  }
}

// ============================================================================
// HELPER: Error Message Mapper
// ============================================================================

class ErrorMessageMapper {
  ErrorMessageMapper._();

  static String mapFirebaseError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('permission-denied') || errorString.contains('permission')) {
      return "You don't have permission to perform this action. Contact your admin if this seems wrong.";
    }
    if (errorString.contains('network') || errorString.contains('socket')) {
      return 'Network error. Check your connection and try again.';
    }
    if (errorString.contains('not-found')) {
      return 'The requested item could not be found. It may have been deleted.';
    }
    if (errorString.contains('already-exists') || errorString.contains('duplicate')) {
      return 'This item already exists. Please use a different name.';
    }
    if (errorString.contains('invalid')) {
      return 'Invalid input. Please check your information and try again.';
    }
    if (errorString.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    if (errorString.contains('quota') || errorString.contains('limit')) {
      return 'Usage limit reached. Please try again later or contact support.';
    }

    // Default user-friendly message
    return 'Something went wrong. Please try again or contact support if the problem persists.';
  }
}
