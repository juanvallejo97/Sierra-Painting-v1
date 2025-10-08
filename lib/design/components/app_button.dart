import 'package:flutter/material.dart';
import 'package:sierra_painting/design/tokens.dart';

/// Primary button component
///
/// Filled button for primary actions with proper touch targets and accessibility.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final ButtonVariant variant;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.variant = ButtonVariant.filled,
  });

  @override
  Widget build(BuildContext context) {
    final Widget child = isLoading
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
        : icon != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: DesignTokens.spaceSM),
              Text(label),
            ],
          )
        : Text(label);

    switch (variant) {
      case ButtonVariant.filled:
        return FilledButton(onPressed: isLoading ? null : onPressed, child: child);
      case ButtonVariant.outlined:
        return OutlinedButton(onPressed: isLoading ? null : onPressed, child: child);
      case ButtonVariant.text:
        return TextButton(onPressed: isLoading ? null : onPressed, child: child);
    }
  }
}

enum ButtonVariant { filled, outlined, text }
