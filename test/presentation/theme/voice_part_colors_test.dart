import 'package:cantae/presentation/theme/cantae_colors.dart';
import 'package:cantae/presentation/theme/voice_part_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VoicePartColors.of — light', () {
    test('soprano', () {
      final color = VoicePartColors.of(VoicePart.soprano, Brightness.light);
      expect(color.background, const Color(0xFFB4512A));
      expect(color.textColor, const Color(0xFFFFFFFF));
      expect(color.outlined, isFalse);
    });

    test('contralto', () {
      final color = VoicePartColors.of(VoicePart.contralto, Brightness.light);
      expect(color.background, const Color(0xFF8E3B66));
      expect(color.textColor, const Color(0xFFFFFFFF));
    });

    test('tenor', () {
      final color = VoicePartColors.of(VoicePart.tenor, Brightness.light);
      expect(color.background, const Color(0xFF2F5F92));
      expect(color.textColor, const Color(0xFFFFFFFF));
    });

    test('baixo', () {
      final color = VoicePartColors.of(VoicePart.baixo, Brightness.light);
      expect(color.background, const Color(0xFF3C6B47));
      expect(color.textColor, const Color(0xFFFFFFFF));
    });

    test('todos', () {
      final color = VoicePartColors.of(VoicePart.todos, Brightness.light);
      expect(color.background, const Color(0xFF1B1B1B));
      expect(color.textColor, const Color(0xFFFFFFFF));
    });

    test('semFaixa is outlined with no fill and text2 as the outline/text color', () {
      final color = VoicePartColors.of(VoicePart.semFaixa, Brightness.light);
      expect(color.outlined, isTrue);
      expect(color.textColor, CantaeColors.light.text2);
    });

    test('visitante is outlined with no fill and text2 as the outline/text color', () {
      final color = VoicePartColors.of(VoicePart.visitante, Brightness.light);
      expect(color.outlined, isTrue);
      expect(color.textColor, CantaeColors.light.text2);
    });
  });

  group('VoicePartColors.of — dark', () {
    test('soprano', () {
      final color = VoicePartColors.of(VoicePart.soprano, Brightness.dark);
      expect(color.background, const Color(0xFFE59B78));
      expect(color.textColor, const Color(0xFF121413));
    });

    test('contralto', () {
      final color = VoicePartColors.of(VoicePart.contralto, Brightness.dark);
      expect(color.background, const Color(0xFFD98BB8));
      expect(color.textColor, const Color(0xFF121413));
    });

    test('tenor', () {
      final color = VoicePartColors.of(VoicePart.tenor, Brightness.dark);
      expect(color.background, const Color(0xFF8DB6E6));
      expect(color.textColor, const Color(0xFF121413));
    });

    test('baixo', () {
      final color = VoicePartColors.of(VoicePart.baixo, Brightness.dark);
      expect(color.background, const Color(0xFF8FC79C));
      expect(color.textColor, const Color(0xFF121413));
    });

    test('todos', () {
      final color = VoicePartColors.of(VoicePart.todos, Brightness.dark);
      expect(color.background, const Color(0xFFEDEDEA));
      expect(color.textColor, const Color(0xFF121413));
    });

    test('semFaixa uses the dark text2', () {
      final color = VoicePartColors.of(VoicePart.semFaixa, Brightness.dark);
      expect(color.outlined, isTrue);
      expect(color.textColor, CantaeColors.dark.text2);
    });

    test('visitante uses the dark text2', () {
      final color = VoicePartColors.of(VoicePart.visitante, Brightness.dark);
      expect(color.outlined, isTrue);
      expect(color.textColor, CantaeColors.dark.text2);
    });
  });
}
