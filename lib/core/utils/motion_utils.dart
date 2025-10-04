import 'package:flutter/material.dart';

/// Utility class for handling motion-reduced animations (WCAG 2.2 AA compliance)
///
/// Detects user's accessibility preference for reduced motion and provides
/// appropriate animation durations.
///
/// Usage:
/// ```dart
/// final duration = MotionUtils.getDuration(
///   context,
///   normal: Duration(milliseconds: 300),
/// );
///
/// AnimatedOpacity(
///   duration: duration,
///   // ...
/// )
/// ```
class MotionUtils {
  /// Get animation duration based on reduced motion preference
  ///
  /// If user has enabled reduced motion in system settings,
  /// returns Duration.zero, otherwise returns the normal duration.
  ///
  /// [context] - BuildContext to access MediaQuery
  /// [normal] - Normal animation duration (default: 300ms)
  /// [reduced] - Optional reduced animation duration (default: Duration.zero)
  static Duration getDuration(
    BuildContext context, {
    Duration normal = const Duration(milliseconds: 300),
    Duration reduced = Duration.zero,
  }) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    return disableAnimations ? reduced : normal;
  }

  /// Get a fast duration for quick animations
  static Duration getFastDuration(BuildContext context) {
    return getDuration(context, normal: const Duration(milliseconds: 150));
  }

  /// Get a medium duration for standard animations
  static Duration getMediumDuration(BuildContext context) {
    return getDuration(context, normal: const Duration(milliseconds: 300));
  }

  /// Get a slow duration for emphasis animations
  static Duration getSlowDuration(BuildContext context) {
    return getDuration(context, normal: const Duration(milliseconds: 500));
  }

  /// Check if animations should be disabled
  static bool shouldDisableAnimations(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }

  /// Get appropriate curve based on motion preference
  ///
  /// Returns linear curve if motion is reduced, otherwise returns the normal curve
  static Curve getCurve(
    BuildContext context, {
    Curve normal = Curves.easeInOut,
  }) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    return disableAnimations ? Curves.linear : normal;
  }
}

/// Extension on BuildContext for convenient access to motion utilities
extension MotionContextExtension on BuildContext {
  /// Get standard animation duration respecting reduced motion preference
  Duration get animationDuration => MotionUtils.getMediumDuration(this);

  /// Get fast animation duration
  Duration get fastAnimationDuration => MotionUtils.getFastDuration(this);

  /// Get slow animation duration
  Duration get slowAnimationDuration => MotionUtils.getSlowDuration(this);

  /// Check if animations are disabled
  bool get animationsDisabled => MotionUtils.shouldDisableAnimations(this);

  /// Get animation curve respecting reduced motion preference
  Curve get animationCurve => MotionUtils.getCurve(this);
}

/// Widget that automatically respects reduced motion preferences
///
/// Wraps AnimatedOpacity with appropriate duration based on user preference
class AccessibleAnimatedOpacity extends StatelessWidget {
  final double opacity;
  final Widget child;
  final Duration? duration;
  final Curve? curve;

  const AccessibleAnimatedOpacity({
    super.key,
    required this.opacity,
    required this.child,
    this.duration,
    this.curve,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: opacity,
      duration: duration ?? context.animationDuration,
      curve: curve ?? context.animationCurve,
      child: child,
    );
  }
}

/// Widget that automatically respects reduced motion preferences
///
/// Wraps AnimatedContainer with appropriate duration based on user preference
class AccessibleAnimatedContainer extends StatelessWidget {
  final Widget? child;
  final AlignmentGeometry? alignment;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Decoration? decoration;
  final Decoration? foregroundDecoration;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final EdgeInsetsGeometry? margin;
  final Matrix4? transform;
  final AlignmentGeometry? transformAlignment;
  final Clip clipBehavior;
  final Duration? duration;
  final Curve? curve;

  const AccessibleAnimatedContainer({
    super.key,
    this.child,
    this.alignment,
    this.padding,
    this.color,
    this.decoration,
    this.foregroundDecoration,
    this.width,
    this.height,
    this.constraints,
    this.margin,
    this.transform,
    this.transformAlignment,
    this.clipBehavior = Clip.none,
    this.duration,
    this.curve,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      alignment: alignment,
      padding: padding,
      color: color,
      decoration: decoration,
      foregroundDecoration: foregroundDecoration,
      width: width,
      height: height,
      constraints: constraints,
      margin: margin,
      transform: transform,
      transformAlignment: transformAlignment,
      clipBehavior: clipBehavior,
      duration: duration ?? context.animationDuration,
      curve: curve ?? context.animationCurve,
      child: child,
    );
  }
}
