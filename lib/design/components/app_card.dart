import 'package:flutter/material.dart';
import 'package:sierra_painting/design/tokens.dart';

/// Reusable card component
///
/// Consistent card styling with proper elevation and radius
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const AppCard({super.key, required this.child, this.onTap, this.padding, this.margin});

  @override
  Widget build(BuildContext context) {
    final card = Card(
      margin: margin,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
        child: Padding(padding: padding ?? const EdgeInsets.all(DesignTokens.spaceMD), child: child),
      ),
    );

    return card;
  }
}
