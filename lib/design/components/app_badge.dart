import 'package:flutter/material.dart';
import 'package:sierra_painting/design/tokens.dart';

/// Badge component for status indicators
///
/// Used for sync status, counts, and state indicators
class AppBadge extends StatelessWidget {
  final String label;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final IconData? icon;
  final BadgeVariant variant;

  const AppBadge({
    super.key,
    required this.label,
    this.backgroundColor,
    this.foregroundColor,
    this.icon,
    this.variant = BadgeVariant.neutral,
  });

  const AppBadge.success({
    super.key,
    required this.label,
    this.icon,
  })  : backgroundColor = DesignTokens.successGreen,
        foregroundColor = Colors.white,
        variant = BadgeVariant.success;

  const AppBadge.warning({
    super.key,
    required this.label,
    this.icon,
  })  : backgroundColor = DesignTokens.warningAmber,
        foregroundColor = Colors.black87,
        variant = BadgeVariant.warning;

  const AppBadge.error({
    super.key,
    required this.label,
    this.icon,
  })  : backgroundColor = DesignTokens.errorRed,
        foregroundColor = Colors.white,
        variant = BadgeVariant.error;

  const AppBadge.info({
    super.key,
    required this.label,
    this.icon,
  })  : backgroundColor = DesignTokens.infoBlue,
        foregroundColor = Colors.white,
        variant = BadgeVariant.info;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveBackgroundColor = backgroundColor ?? 
        _getDefaultBackgroundColor(colorScheme);
    final effectiveForegroundColor = foregroundColor ?? 
        _getDefaultForegroundColor(colorScheme);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceMD,
        vertical: DesignTokens.spaceXS,
      ),
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: effectiveForegroundColor,
            ),
            const SizedBox(width: DesignTokens.spaceXS),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: effectiveForegroundColor,
            ),
          ),
        ],
      ),
    );
  }

  Color _getDefaultBackgroundColor(ColorScheme colorScheme) {
    switch (variant) {
      case BadgeVariant.success:
        return DesignTokens.successGreen;
      case BadgeVariant.warning:
        return DesignTokens.warningAmber;
      case BadgeVariant.error:
        return DesignTokens.errorRed;
      case BadgeVariant.info:
        return DesignTokens.infoBlue;
      case BadgeVariant.neutral:
        return colorScheme.surfaceContainerHighest;
    }
  }

  Color _getDefaultForegroundColor(ColorScheme colorScheme) {
    switch (variant) {
      case BadgeVariant.success:
      case BadgeVariant.error:
      case BadgeVariant.info:
        return Colors.white;
      case BadgeVariant.warning:
        return Colors.black87;
      case BadgeVariant.neutral:
        return colorScheme.onSurface;
    }
  }
}

enum BadgeVariant {
  neutral,
  success,
  warning,
  error,
  info,
}
