import 'package:flutter/material.dart';

ThemeData buildTheme({
  required Brightness brightness,
  required Color seed,
  required double radius,
  required double density,
}) {
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  final shapes = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radius),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    visualDensity: VisualDensity(horizontal: density, vertical: density),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
    ),
    cardTheme: CardThemeData(
      margin: const EdgeInsets.all(12),
      shape: shapes,
      elevation: 1,
    ),
    dialogTheme: DialogThemeData(shape: shapes),
    chipTheme: ChipThemeData(
      side: BorderSide(color: scheme.outlineVariant),
      shape: shapes,
      selectedColor: scheme.secondaryContainer,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(shape: WidgetStatePropertyAll(shapes)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius)),
    ),
  );
}
