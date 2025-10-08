import 'package:flutter/material.dart';
import 'package:sierra_painting/design/design.dart';

/// Empty state widget for list screens
///
/// Displays helpful guidance when no data is available.
/// Includes optional action button for creating new items.
class AppEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 120, color: theme.colorScheme.primary.withValues(alpha: 0.3)),
            const SizedBox(height: DesignTokens.spaceLG),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.spaceSM),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: DesignTokens.spaceXL),
              AppButton(label: actionLabel!, icon: Icons.add, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}
