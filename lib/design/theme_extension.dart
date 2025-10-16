import 'package:flutter/material.dart';

/// Theme extension for accessibility and motion preferences
///
/// Provides runtime theme extensions for:
/// - Reduce Motion support (prefers-reduced-motion)
/// - High Contrast mode
/// - Text scaling awareness
/// - RTL language support
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  /// Whether to reduce motion/animations
  final bool reduceMotion;

  /// Whether high contrast mode is enabled
  final bool highContrast;

  /// Current text scale factor (1.0 = normal, 2.0 = 200%)
  final double textScale;

  /// Whether the current locale is RTL
  final bool isRTL;

  const AppThemeExtension({
    this.reduceMotion = false,
    this.highContrast = false,
    this.textScale = 1.0,
    this.isRTL = false,
  });

  /// Get animation duration based on reduce motion preference
  Duration getAnimationDuration(Duration normalDuration) {
    if (reduceMotion) {
      // Reduce to instant or very fast
      return Duration(milliseconds: (normalDuration.inMilliseconds * 0.1).round());
    }
    return normalDuration;
  }

  /// Get appropriate elevation for high contrast mode
  double getElevation(double normalElevation) {
    if (highContrast) {
      // Increase elevation in high contrast for better separation
      return normalElevation * 1.5;
    }
    return normalElevation;
  }

  /// Whether animations should be disabled entirely
  bool get disableAnimations => reduceMotion;

  @override
  ThemeExtension<AppThemeExtension> copyWith({
    bool? reduceMotion,
    bool? highContrast,
    double? textScale,
    bool? isRTL,
  }) {
    return AppThemeExtension(
      reduceMotion: reduceMotion ?? this.reduceMotion,
      highContrast: highContrast ?? this.highContrast,
      textScale: textScale ?? this.textScale,
      isRTL: isRTL ?? this.isRTL,
    );
  }

  @override
  ThemeExtension<AppThemeExtension> lerp(
    covariant ThemeExtension<AppThemeExtension>? other,
    double t,
  ) {
    if (other is! AppThemeExtension) return this;

    return AppThemeExtension(
      reduceMotion: t < 0.5 ? reduceMotion : other.reduceMotion,
      highContrast: t < 0.5 ? highContrast : other.highContrast,
      textScale: (textScale * (1 - t)) + (other.textScale * t),
      isRTL: t < 0.5 ? isRTL : other.isRTL,
    );
  }

  /// Create from MediaQuery data
  static AppThemeExtension fromMediaQuery(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return AppThemeExtension(
      reduceMotion: mediaQuery.disableAnimations,
      highContrast: mediaQuery.highContrast,
      textScale: mediaQuery.textScaleFactor,
      isRTL: Directionality.of(context) == TextDirection.rtl,
    );
  }
}

/// Helper extension to easily access AppThemeExtension
extension ThemeDataExtensions on ThemeData {
  AppThemeExtension get appExtension {
    return extension<AppThemeExtension>() ?? const AppThemeExtension();
  }
}
