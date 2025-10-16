/// PHASE 2: SKELETON CODE - Accessible Widget Components
///
/// PURPOSE:
/// - WCAG 2.2 AA compliant widgets
/// - Proper contrast ratios (4.5:1 for text, 3:1 for UI)
/// - Keyboard navigation support
/// - Screen reader friendly
/// - Focus management
/// - Never rely on color alone for status

library accessible_widgets;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================================
// A11Y CARD - Accessible Card Component
// ============================================================================

class A11yCard extends StatelessWidget {
  final Widget child;
  final String? semanticLabel;
  final VoidCallback? onTap;
  final bool excludeSemantics;
  final Color? backgroundColor;

  const A11yCard({
    super.key,
    required this.child,
    this.semanticLabel,
    this.onTap,
    this.excludeSemantics = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      excludeSemantics: excludeSemantics,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: _buildCard(context),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    // TODO(Phase 3): Calculate contrast ratios and adjust colors
    final bgColor = backgroundColor ?? _getAccessibleBackgroundColor(context);

    return Card(
      color: bgColor,
      elevation: _getAccessibleElevation(context),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }

  Color _getAccessibleBackgroundColor(BuildContext context) {
    // TODO(Phase 3): Ensure 4.5:1 contrast ratio
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return brightness == Brightness.dark ? Colors.grey[850]! : Colors.white;
  }

  double _getAccessibleElevation(BuildContext context) {
    // TODO(Phase 3): Increase elevation in high contrast mode
    final highContrast = MediaQuery.of(context).highContrast;
    return highContrast ? 4.0 : 2.0;
  }
}

// ============================================================================
// STATUS CHIP - Status Indicator with Icon + Text + Color
// ============================================================================

enum StatusType {
  active,
  pending,
  error,
  success,
  warning,
  info,
}

class StatusChip extends StatelessWidget {
  final StatusType status;
  final String? customLabel;
  final bool compact;

  const StatusChip({
    super.key,
    required this.status,
    this.customLabel,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getStatusConfig();

    return Semantics(
      label: 'Status: ${customLabel ?? config.label}',
      liveRegion: true,
      child: Chip(
        avatar: Icon(config.icon, size: 16, color: config.color),
        label: Text(
          customLabel ?? config.label,
          style: TextStyle(
            color: _getContrastingTextColor(config.backgroundColor),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: config.backgroundColor,
      ),
    );
  }

  _StatusConfig _getStatusConfig() {
    // TODO(Phase 3): Load colors from theme
    switch (status) {
      case StatusType.active:
        return _StatusConfig(
          icon: Icons.check_circle,
          label: 'Active',
          color: Colors.green[700]!,
          backgroundColor: Colors.green[50]!,
        );
      case StatusType.pending:
        return _StatusConfig(
          icon: Icons.schedule,
          label: 'Pending',
          color: Colors.orange[700]!,
          backgroundColor: Colors.orange[50]!,
        );
      case StatusType.error:
        return _StatusConfig(
          icon: Icons.error_outline,
          label: 'Error',
          color: Colors.red[700]!,
          backgroundColor: Colors.red[50]!,
        );
      case StatusType.success:
        return _StatusConfig(
          icon: Icons.check_circle_outline,
          label: 'Success',
          color: Colors.green[700]!,
          backgroundColor: Colors.green[50]!,
        );
      case StatusType.warning:
        return _StatusConfig(
          icon: Icons.warning_amber,
          label: 'Warning',
          color: Colors.amber[700]!,
          backgroundColor: Colors.amber[50]!,
        );
      case StatusType.info:
        return _StatusConfig(
          icon: Icons.info_outline,
          label: 'Info',
          color: Colors.blue[700]!,
          backgroundColor: Colors.blue[50]!,
        );
    }
  }

  Color _getContrastingTextColor(Color backgroundColor) {
    // TODO(Phase 3): Calculate proper contrast ratio
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }
}

class _StatusConfig {
  final IconData icon;
  final String label;
  final Color color;
  final Color backgroundColor;

  const _StatusConfig({
    required this.icon,
    required this.label,
    required this.color,
    required this.backgroundColor,
  });
}

// ============================================================================
// A11Y BUTTON - Accessible Button Component
// ============================================================================

class A11yButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool isLoading;
  final ButtonStyle? style;
  final String? semanticLabel;

  const A11yButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.isLoading = false,
    this.style,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: onPressed != null && !isLoading,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: _getAccessibleButtonStyle(context),
        child: isLoading ? _buildLoadingIndicator() : child,
      ),
    );
  }

  ButtonStyle _getAccessibleButtonStyle(BuildContext context) {
    // TODO(Phase 3): Ensure minimum 44x44 touch target
    return (style ?? FilledButton.styleFrom()).copyWith(
      minimumSize: MaterialStateProperty.all(const Size(44, 44)),
      padding: MaterialStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      // Visible focus ring
      overlayColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.focused)) {
          return Theme.of(context).colorScheme.primary.withOpacity(0.12);
        }
        return null;
      }),
    );
  }

  Widget _buildLoadingIndicator() {
    return const SizedBox(
      height: 16,
      width: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }
}

// ============================================================================
// FOCUSABLE CONTAINER - Keyboard Focus Support
// ============================================================================

class FocusableContainer extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool autofocus;

  const FocusableContainer({
    super.key,
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.autofocus = false,
  });

  @override
  State<FocusableContainer> createState() => _FocusableContainerState();
}

class _FocusableContainerState extends State<FocusableContainer> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      button: widget.onTap != null,
      child: Focus(
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        onKey: _handleKeyPress,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            decoration: _isFocused ? _buildFocusDecoration(context) : null,
            child: widget.child,
          ),
        ),
      ),
    );
  }

  KeyEventResult _handleKeyPress(FocusNode node, RawKeyEvent event) {
    // TODO(Phase 3): Handle keyboard events
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.space) {
        widget.onTap?.call();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  BoxDecoration _buildFocusDecoration(BuildContext context) {
    // TODO(Phase 3): Make focus ring more visible
    return BoxDecoration(
      border: Border.all(
        color: Theme.of(context).colorScheme.primary,
        width: 2,
      ),
      borderRadius: BorderRadius.circular(8),
    );
  }
}
