import 'package:cantae/presentation/theme/cantae_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CantaeColors.light', () {
    test('accent and bg match the documented light-mode hex values', () {
      expect(CantaeColors.light.accent, const Color(0xFF0E5E4B));
      expect(CantaeColors.light.bg, const Color(0xFFF4F4F2));
    });
  });

  group('CantaeColors.dark', () {
    test('accent and bg match the documented dark-mode hex values', () {
      expect(CantaeColors.dark.accent, const Color(0xFF5FC4A3));
      expect(CantaeColors.dark.bg, const Color(0xFF121413));
    });

    test('dark accent differs from light accent', () {
      expect(CantaeColors.dark.accent, isNot(CantaeColors.light.accent));
    });
  });
}
