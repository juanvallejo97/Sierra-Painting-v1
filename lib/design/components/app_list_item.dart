import 'package:flutter/material.dart';
import 'package:sierra_painting/design/tokens.dart';

/// List item component
///
/// Consistent list tile with proper spacing and touch targets
class AppListItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  const AppListItem({super.key, required this.title, this.subtitle, this.leading, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading != null ? Icon(leading) : null,
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing,
      onTap: onTap,
      minVerticalPadding: DesignTokens.spaceSM,
      contentPadding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMD, vertical: DesignTokens.spaceSM),
    );
  }
}
