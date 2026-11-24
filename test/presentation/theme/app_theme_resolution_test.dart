import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/theme/cantae_colors.dart';
import 'package:cantae/presentation/theme/cantae_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme', () {
    test('defaultThemeMode is system', () {
      expect(AppTheme.defaultThemeMode, ThemeMode.system);
    });

    test('light theme carries the light CantaeColors extension', () {
      final colors = AppTheme.light.extension<CantaeColors>();
      expect(colors, isNotNull);
      expect(colors!.accent, CantaeColors.light.accent);
    });

    test('dark theme carries the dark CantaeColors extension', () {
      final colors = AppTheme.dark.extension<CantaeColors>();
      expect(colors, isNotNull);
      expect(colors!.accent, CantaeColors.dark.accent);
    });

    test('light theme textTheme.bodyLarge resolves the body typography token',
        () {
      final bodyLarge = AppTheme.light.textTheme.bodyLarge!;
      expect(bodyLarge.fontFamily, CantaeTypography.body.fontFamily);
      expect(bodyLarge.fontSize, CantaeTypography.body.fontSize);
      expect(bodyLarge.fontWeight, CantaeTypography.body.fontWeight);
    });

    test(
        'light theme textTheme.headlineLarge resolves the titleHub typography token',
        () {
      final headlineLarge = AppTheme.light.textTheme.headlineLarge!;
      expect(headlineLarge.fontFamily, CantaeTypography.titleHub.fontFamily);
      expect(headlineLarge.fontSize, CantaeTypography.titleHub.fontSize);
    });
  });
}
