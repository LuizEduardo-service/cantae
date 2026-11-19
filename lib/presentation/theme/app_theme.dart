import 'package:flutter/material.dart';

import 'cantae_colors.dart';
import 'cantae_typography.dart';

/// Builds the app's light and dark `ThemeData` from the token layer.
/// No screen should build its own `ThemeData` — both themes come from here.
abstract final class AppTheme {
  /// DESIGN_SYSTEM §9: theme mode is controlled by the Profile preference
  /// (Claro/Escuro/Sistema), not fixed here. This is only the default a
  /// `MaterialApp` should start with before that preference loads.
  static const ThemeMode defaultThemeMode = ThemeMode.system;

  static final ThemeData light = _build(
    brightness: Brightness.light,
    colors: CantaeColors.light,
  );

  static final ThemeData dark = _build(
    brightness: Brightness.dark,
    colors: CantaeColors.dark,
  );

  static ThemeData _build({
    required Brightness brightness,
    required CantaeColors colors,
  }) {
    return ThemeData(
      brightness: brightness,
      fontFamily: 'Geist',
      scaffoldBackgroundColor: colors.bg,
      extensions: [colors],
      textTheme: const TextTheme(
        displayLarge: CantaeTypography.display,
        headlineLarge: CantaeTypography.titleHub,
        headlineMedium: CantaeTypography.titlePage,
        headlineSmall: CantaeTypography.titleRoom,
        titleLarge: CantaeTypography.titleSheet,
        titleMedium: CantaeTypography.listTitle,
        bodyLarge: CantaeTypography.body,
        bodyMedium: CantaeTypography.bodySmall,
        labelLarge: CantaeTypography.label,
        labelSmall: CantaeTypography.caption,
      ).apply(
        bodyColor: colors.text,
        displayColor: colors.text,
      ),
    );
  }
}
