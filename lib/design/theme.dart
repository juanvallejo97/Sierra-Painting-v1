/// Sierra Painting theme configuration
///
/// Implements Material 3 themes using design tokens.
/// Ensures WCAG 2.2 AA compliance with proper contrast ratios.
/// Supports light and dark themes with smooth transitions.
library;

import 'package:flutter/material.dart';
import 'package:sierra_painting/design/tokens.dart';

class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  // ============================================================================
  // LIGHT THEME
  // ============================================================================

  static ThemeData get light {
    final colorScheme = const ColorScheme.light(
      primary: DesignTokens.dsierraRed,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFFFDAD6),
      onPrimaryContainer: Color(0xFF410002),
      secondary: Color(0xFF775652),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFFFDAD6),
      onSecondaryContainer: Color(0xFF2C1512),
      tertiary: DesignTokens.successGreen,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFC8E6C9),
      onTertiaryContainer: Color(0xFF002106),
      error: DesignTokens.errorRed,
      onError: Colors.white,
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      surface: DesignTokens.surfaceLight,
      onSurface: Color(0xFF1A1C1E),
      surfaceContainerHighest: DesignTokens.surfaceElevation3Light,
      onSurfaceVariant: Color(0xFF43474E),
      outline: Color(0xFF73777F),
      outlineVariant: Color(0xFFC3C7CF),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFF2F3033),
      onInverseSurface: Color(0xFFF1F0F4),
      inversePrimary: Color(0xFFFFB4AB),
    );

    return _buildTheme(colorScheme, Brightness.light);
  }

  // ============================================================================
  // DARK THEME
  // ============================================================================

  static ThemeData get dark {
    final colorScheme = const ColorScheme.dark(
      primary: Color(0xFFFFB4AB),
      onPrimary: Color(0xFF690005),
      primaryContainer: Color(0xFF93000A),
      onPrimaryContainer: Color(0xFFFFDAD6),
      secondary: Color(0xFFE7BDB7),
      onSecondary: Color(0xFF442926),
      secondaryContainer: Color(0xFF5D3F3C),
      onSecondaryContainer: Color(0xFFFFDAD6),
      tertiary: Color(0xFF81C784),
      onTertiary: Color(0xFF003910),
      tertiaryContainer: Color(0xFF005319),
      onTertiaryContainer: Color(0xFFC8E6C9),
      error: Color(0xFFEF5350),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: DesignTokens.surfaceDark,
      onSurface: Color(0xFFE3E2E6),
      surfaceContainerHighest: DesignTokens.surfaceElevation3Dark,
      onSurfaceVariant: Color(0xFFC3C7CF),
      outline: Color(0xFF8D9199),
      outlineVariant: Color(0xFF43474E),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFFE3E2E6),
      onInverseSurface: Color(0xFF1A1C1E),
      inversePrimary: Color(0xFFB71C1C),
    );

    return _buildTheme(colorScheme, Brightness.dark);
  }

  // ============================================================================
  // SHARED THEME CONFIGURATION
  // ============================================================================

  static ThemeData _buildTheme(ColorScheme colorScheme, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,

      // Accessibility: Minimum touch target size
      materialTapTargetSize: MaterialTapTargetSize.padded,

      // Visual density - standard for mobile
      visualDensity: VisualDensity.standard,

      // Typography with proper scale
      textTheme: _buildTextTheme(colorScheme),

      // App bar theme
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: DesignTokens.elevation0,
        scrolledUnderElevation: DesignTokens.elevation1,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: colorScheme.surfaceTint,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
      ),

      cardTheme: const CardThemeData(),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceMD,
          vertical: DesignTokens.spaceMD,
        ),
      ),

      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(88, DesignTokens.touchTargetComfortable),
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceLG,
            vertical: DesignTokens.spaceMD,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(88, DesignTokens.touchTargetComfortable),
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceLG,
            vertical: DesignTokens.spaceMD,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(88, DesignTokens.touchTargetComfortable),
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceLG,
            vertical: DesignTokens.spaceMD,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(88, DesignTokens.touchTargetComfortable),
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceLG,
            vertical: DesignTokens.spaceMD,
          ),
        ),
      ),

      // FAB theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: DesignTokens.elevation2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusXL),
        ),
      ),

      // Navigation bar theme
      navigationBarTheme: const NavigationBarThemeData(
        elevation: DesignTokens.elevation1,
        height: 80,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),

      // Drawer theme
      drawerTheme: const DrawerThemeData(
        elevation: DesignTokens.elevation4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(DesignTokens.radiusXL),
            bottomRight: Radius.circular(DesignTokens.radiusXL),
          ),
        ),
      ),

      // List tile theme
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: DesignTokens.spaceSM,
        contentPadding: EdgeInsets.symmetric(horizontal: DesignTokens.spaceMD),
      ),

      // Chip theme
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceMD,
          vertical: DesignTokens.spaceSM,
        ),
      ),

      // Divider theme
      dividerTheme: DividerThemeData(
        space: DesignTokens.spaceMD,
        thickness: 1,
        color: colorScheme.outlineVariant,
      ),

      // Snackbar theme
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        ),
        actionTextColor: colorScheme.inversePrimary,
      ),

      dialogTheme: const DialogThemeData(),

      // Bottom sheet theme
      bottomSheetTheme: const BottomSheetThemeData(
        elevation: DesignTokens.elevation3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(DesignTokens.radiusXL),
            topRight: Radius.circular(DesignTokens.radiusXL),
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),
    );
  }

  // ============================================================================
  // TEXT THEME
  // ============================================================================

  static TextTheme _buildTextTheme(ColorScheme colorScheme) {
    return TextTheme(
      // Display styles
      displayLarge: TextStyle(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
        height: 1.12,
        color: colorScheme.onSurface,
      ),
      displayMedium: TextStyle(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.16,
        color: colorScheme.onSurface,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.22,
        color: colorScheme.onSurface,
      ),

      // Headline styles
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.25,
        color: colorScheme.onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.29,
        color: colorScheme.onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.33,
        color: colorScheme.onSurface,
      ),

      // Title styles
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.27,
        color: colorScheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
        height: 1.5,
        color: colorScheme.onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        height: 1.43,
        color: colorScheme.onSurface,
      ),

      // Body styles
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        height: 1.5,
        color: colorScheme.onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        height: 1.43,
        color: colorScheme.onSurface,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        height: 1.33,
        color: colorScheme.onSurfaceVariant,
      ),

      // Label styles
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        height: 1.43,
        color: colorScheme.onSurface,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.33,
        color: colorScheme.onSurface,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.45,
        color: colorScheme.onSurface,
      ),
    );
  }
}
