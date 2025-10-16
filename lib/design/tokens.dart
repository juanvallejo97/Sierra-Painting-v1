import 'package:flutter/material.dart';

/// Design tokens for Sierra Painting
///
/// Comprehensive token system following Material 3 and WCAG 2.2 AA guidelines.
/// Provides semantic color palette, spacing scale, typography, and motion.
///
/// Professional + family-friendly tone: warm, modern, clean, trustworthy.
class DesignTokens {
  // Private constructor to prevent instantiation
  DesignTokens._();

  // ============================================================================
  // BRAND COLORS (D'Sierra Painting)
  // ============================================================================

  /// Primary brand color - D'Sierra Red
  /// Bold, professional, trustworthy
  static const Color dsierraRed = Color(0xFFB71C1C);

  /// Legacy colors (deprecated - use dsierraRed instead)
  @Deprecated('Use dsierraRed instead')
  static const Color sierraBlue = Color(0xFF1976D2);

  @Deprecated('Use dsierraRed for primary actions')
  static const Color paintingOrange = Color(0xFFFF9800);

  // ============================================================================
  // SEMANTIC COLORS
  // ============================================================================

  /// Success state - actions completed, synced
  static const Color successGreen = Color(0xFF4CAF50);

  /// Warning state - pending sync, caution
  static const Color warningAmber = Color(0xFFFFA726);

  /// Error state - failures, critical issues
  static const Color errorRed = Color(0xFFD32F2F);

  /// Info state - informational messages
  static const Color infoBlue = Color(0xFF2196F3);

  // ============================================================================
  // SURFACE VARIANTS (Light Theme)
  // ============================================================================

  /// Base surface color
  static const Color surfaceLight = Color(0xFFFAFAFA);

  /// Elevated surface level 1
  static const Color surfaceElevation1Light = Color(0xFFF5F5F5);

  /// Elevated surface level 2
  static const Color surfaceElevation2Light = Color(0xFFEEEEEE);

  /// Elevated surface level 3
  static const Color surfaceElevation3Light = Color(0xFFE0E0E0);

  // ============================================================================
  // SURFACE VARIANTS (Dark Theme)
  // ============================================================================

  /// Base surface color (dark)
  static const Color surfaceDark = Color(0xFF121212);

  /// Elevated surface level 1 (dark)
  static const Color surfaceElevation1Dark = Color(0xFF1E1E1E);

  /// Elevated surface level 2 (dark)
  static const Color surfaceElevation2Dark = Color(0xFF2A2A2A);

  /// Elevated surface level 3 (dark)
  static const Color surfaceElevation3Dark = Color(0xFF363636);

  // ============================================================================
  // SPACING SCALE
  // ============================================================================

  /// Extra small spacing - 4.0
  static const double spaceXS = 4.0;

  /// Small spacing - 8.0
  static const double spaceSM = 8.0;

  /// Medium spacing - 16.0
  static const double spaceMD = 16.0;

  /// Large spacing - 24.0
  static const double spaceLG = 24.0;

  /// Extra large spacing - 32.0
  static const double spaceXL = 32.0;

  /// Extra extra large spacing - 48.0
  static const double spaceXXL = 48.0;

  // ============================================================================
  // BORDER RADIUS
  // ============================================================================

  /// Small radius - 4.0
  static const double radiusSM = 4.0;

  /// Medium radius - 8.0
  static const double radiusMD = 8.0;

  /// Large radius - 12.0
  static const double radiusLG = 12.0;

  /// Extra large radius - 16.0
  static const double radiusXL = 16.0;

  /// Full radius - 999.0 (pill shape)
  static const double radiusFull = 999.0;

  // ============================================================================
  // ELEVATION
  // ============================================================================

  /// No elevation
  static const double elevation0 = 0.0;

  /// Low elevation
  static const double elevation1 = 1.0;

  /// Medium elevation
  static const double elevation2 = 2.0;

  /// High elevation
  static const double elevation3 = 4.0;

  /// Very high elevation
  static const double elevation4 = 8.0;

  // ============================================================================
  // MOTION DURATIONS (Professional, subtle)
  // ============================================================================

  /// Extra fast motion - 100ms
  static const Duration motionXFast = Duration(milliseconds: 100);

  /// Fast motion - 150ms
  static const Duration motionFast = Duration(milliseconds: 150);

  /// Medium motion - 200ms
  static const Duration motionMedium = Duration(milliseconds: 200);

  /// Slow motion - 300ms
  static const Duration motionSlow = Duration(milliseconds: 300);

  /// Extra slow motion - 500ms
  static const Duration motionXSlow = Duration(milliseconds: 500);

  // ============================================================================
  // TOUCH TARGETS (WCAG 2.2 AA)
  // ============================================================================

  /// Minimum touch target size - 44.0
  static const double touchTargetMin = 44.0;

  /// Comfortable touch target - 48.0
  static const double touchTargetComfortable = 48.0;

  /// Large touch target - 56.0
  static const double touchTargetLarge = 56.0;

  // ============================================================================
  // OPACITY LEVELS
  // ============================================================================

  /// Disabled state opacity
  static const double opacityDisabled = 0.38;

  /// Hover state opacity
  static const double opacityHover = 0.08;

  /// Focus state opacity
  static const double opacityFocus = 0.12;

  /// Selected state opacity
  static const double opacitySelected = 0.12;

  /// Pressed state opacity
  static const double opacityPressed = 0.12;

  // ============================================================================
  // TYPOGRAPHY SIZES (Material 3 Scale)
  // ============================================================================

  static const double fontSizeDisplay = 57.0;
  static const double fontSizeHeadline = 32.0;
  static const double fontSizeTitle = 22.0;
  static const double fontSizeBody = 16.0;
  static const double fontSizeLabel = 14.0;
  static const double fontSizeCaption = 12.0;
}
