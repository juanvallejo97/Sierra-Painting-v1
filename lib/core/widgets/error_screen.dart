import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sierra_painting/design/design.dart';

class ErrorScreen extends StatelessWidget {
  final Exception? error;
  final String? path;

  const ErrorScreen({super.key, this.error, this.path});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNotFound =
        error.toString().contains('not found') ||
        error.toString().contains('404');

    return Scaffold(
      appBar: AppBar(title: Text(isNotFound ? 'Page Not Found' : 'Error')),
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
                const Text(
                  'The page you are looking for does not exist.',
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
                const Text(
                  'We encountered an unexpected error. Please try again.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DesignTokens.spaceSM),
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
                const Text(
                  'Something unexpected happened. Please try again.',
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
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/timeclock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}