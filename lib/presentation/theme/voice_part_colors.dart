import 'package:flutter/material.dart';

import 'cantae_colors.dart';

/// The seven naipe/role identities from `docs/design/DESIGN_SYSTEM.md` §2.3.
/// Always paired with a letter or name in the UI — never color alone.
enum VoicePart { soprano, contralto, tenor, baixo, todos, semFaixa, visitante }

/// A naipe's background and text color for one theme brightness.
@immutable
class VoicePartColor {
  const VoicePartColor({
    required this.background,
    required this.textColor,
    this.outlined = false,
  });

  final Color background;
  final Color textColor;

  /// `semFaixa` and `visitante` render as a dashed/solid outline with a
  /// transparent fill rather than a solid background (DESIGN_SYSTEM §2.3).
  final bool outlined;
}

/// Resolves a [VoicePart]'s documented color pair for a given [Brightness].
abstract final class VoicePartColors {
  static VoicePartColor of(VoicePart part, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    switch (part) {
      case VoicePart.soprano:
        return VoicePartColor(
          background: isDark ? const Color(0xFFE59B78) : const Color(0xFFB4512A),
          textColor: isDark ? const Color(0xFF121413) : const Color(0xFFFFFFFF),
        );
      case VoicePart.contralto:
        return VoicePartColor(
          background: isDark ? const Color(0xFFD98BB8) : const Color(0xFF8E3B66),
          textColor: isDark ? const Color(0xFF121413) : const Color(0xFFFFFFFF),
        );
      case VoicePart.tenor:
        return VoicePartColor(
          background: isDark ? const Color(0xFF8DB6E6) : const Color(0xFF2F5F92),
          textColor: isDark ? const Color(0xFF121413) : const Color(0xFFFFFFFF),
        );
      case VoicePart.baixo:
        return VoicePartColor(
          background: isDark ? const Color(0xFF8FC79C) : const Color(0xFF3C6B47),
          textColor: isDark ? const Color(0xFF121413) : const Color(0xFFFFFFFF),
        );
      case VoicePart.todos:
        return VoicePartColor(
          background: isDark ? const Color(0xFFEDEDEA) : const Color(0xFF1B1B1B),
          textColor: isDark ? const Color(0xFF121413) : const Color(0xFFFFFFFF),
        );
      case VoicePart.semFaixa:
        final text2 = isDark ? CantaeColors.dark.text2 : CantaeColors.light.text2;
        return VoicePartColor(
          background: const Color(0x00000000),
          textColor: text2,
          outlined: true,
        );
      case VoicePart.visitante:
        final text2 = isDark ? CantaeColors.dark.text2 : CantaeColors.light.text2;
        return VoicePartColor(
          background: const Color(0x00000000),
          textColor: text2,
          outlined: true,
        );
    }
  }
}
