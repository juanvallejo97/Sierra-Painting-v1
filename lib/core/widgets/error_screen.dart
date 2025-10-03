import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sierra_painting/design/design.dart';

/// Error screen displayed when navigation errors occur
///
/// Handles:
/// - 404 Not Found errors
/// - Route parsing errors
/// - Authentication errors
/// - General navigation failures
///
/// Provides:
/// - User-friendly error message
/// - Navigation back to home
/// - Optional error details (debug mode)
class ErrorScreen extends StatelessWidget {
  final Exception? error;
  final String? path;

  const ErrorScreen({
    super.key,
    this.error,
    this.path,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNotFound = error.toString().contains('not found') ||
        error.toString().contains('404');

    return Scaffold(
      appBar: AppBar(
        title: Text(isNotFound ? 'Page Not Found' : 'Error'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spaceLG),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isNotFound ? Icons.search_off : Icons.error_outline,
                size: 120,
                color: theme.colorScheme.error.withOpacity(0.7),
              ),
              const SizedBox(height: DesignTokens.spaceLG),
              Text(
                isNotFound ? 'Page Not Found' : 'Oops! Something Went Wrong',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DesignTokens.spaceMD),
              if (path != null) ...[
                Text(
                  'The page you're looking for doesn't exist.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DesignTokens.spaceSM),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceMD,
                    vertical: DesignTokens.spaceSM,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                  ),
                  child: Text(
                    path!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ] else if (error != null) ...[
                Text(
                  'We encountered an unexpected error. Please try again.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DesignTokens.spaceSM),
                if (error != null)
                  Text(
                    error.toString(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ] else ...[
                Text(
                  'Something unexpected happened. Please try again.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: DesignTokens.spaceXL),
              AppButton(
                label: 'Go to Home',
                icon: Icons.home,
                onPressed: () => context.go('/timeclock'),
              ),
              const SizedBox(height: DesignTokens.spaceSM),
              AppButton(
                label: 'Go Back',
                icon: Icons.arrow_back,
                variant: ButtonVariant.text,
                onPressed: () => context.canPop() 
                    ? context.pop() 
                    : context.go('/timeclock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
