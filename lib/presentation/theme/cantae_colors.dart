import 'package:flutter/material.dart';

/// Semantic color tokens from `docs/design/DESIGN_SYSTEM.md` §2. No widget
/// should ever use a literal hex value — read these via
/// `Theme.of(context).extension<CantaeColors>()`.
@immutable
class CantaeColors extends ThemeExtension<CantaeColors> {
  const CantaeColors({
    required this.bg,
    required this.surface,
    required this.fillField,
    required this.fillMuted,
    required this.fillSecondary,
    required this.fillOnSurface,
    required this.divider,
    required this.segmentSelected,
    required this.text,
    required this.textBody,
    required this.text2,
    required this.text3,
    required this.textDisabled,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.onAccentSoft,
    required this.accentTrack,
    required this.warningBg,
    required this.onWarning,
    required this.warningInline,
    required this.dangerBg,
    required this.onDanger,
    required this.dangerSolid,
    required this.toastBg,
    required this.onToast,
    required this.scrim,
    required this.switchOff,
  });

  final Color bg;
  final Color surface;
  final Color fillField;
  final Color fillMuted;
  final Color fillSecondary;
  final Color fillOnSurface;
  final Color divider;
  final Color segmentSelected;
  final Color text;
  final Color textBody;
  final Color text2;
  final Color text3;
  final Color textDisabled;
  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color onAccentSoft;
  final Color accentTrack;
  final Color warningBg;
  final Color onWarning;
  final Color warningInline;
  final Color dangerBg;
  final Color onDanger;
  final Color dangerSolid;
  final Color toastBg;
  final Color onToast;
  final Color scrim;
  final Color switchOff;

  static const CantaeColors light = CantaeColors(
    bg: Color(0xFFF4F4F2),
    surface: Color(0xFFFFFFFF),
    fillField: Color(0xFFE8E8E4),
    fillMuted: Color(0xFFE6E6E2),
    fillSecondary: Color(0xFFE2E2DD),
    fillOnSurface: Color(0xFFF0F0EC),
    divider: Color(0xFFEFEFEB),
    segmentSelected: Color(0xFFFFFFFF),
    text: Color(0xFF1B1B1B),
    textBody: Color(0xFF3E3E3A),
    text2: Color(0xFF55554F),
    text3: Color(0xFF6E6E69),
    textDisabled: Color(0xFF8A8A85),
    accent: Color(0xFF0E5E4B),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFE3EFEA),
    onAccentSoft: Color(0xFF0B4A3B),
    accentTrack: Color(0xFFBFDCD1),
    warningBg: Color(0xFFFBF0DC),
    onWarning: Color(0xFF4A2C00),
    warningInline: Color(0xFF8A5200),
    dangerBg: Color(0xFFFBE9E7),
    onDanger: Color(0xFF8C1D16),
    dangerSolid: Color(0xFFB3261E),
    toastBg: Color(0xFF1B1B1B),
    onToast: Color(0xFFFFFFFF),
    scrim: Color(0x73141412),
    switchOff: Color(0xFFB8B8B2),
  );

  static const CantaeColors dark = CantaeColors(
    bg: Color(0xFF121413),
    surface: Color(0xFF1E2120),
    fillField: Color(0xFF262A28),
    fillMuted: Color(0xFF2A2E2C),
    fillSecondary: Color(0xFF2A2E2C),
    fillOnSurface: Color(0xFF262A28),
    divider: Color(0xFF2A2E2C),
    segmentSelected: Color(0xFF3A3F3C),
    text: Color(0xFFEDEDEA),
    textBody: Color(0xFFC9CCC8),
    text2: Color(0xFFA6A9A5),
    text3: Color(0xFF8B8E8A),
    // SPEC_DEVIATION: DESIGN_SYSTEM.md §2.2 has no dedicated dark-mode row
    // for textDisabled. Reusing text3's dark value, mirroring how the doc
    // itself collapses fillField/fillOnSurface into one dark-mode row.
    textDisabled: Color(0xFF8B8E8A),
    accent: Color(0xFF5FC4A3),
    onAccent: Color(0xFF0B1F18),
    accentSoft: Color(0xFF173A30),
    onAccentSoft: Color(0xFF9FE3CB),
    accentTrack: Color(0xFF1F4A3D),
    warningBg: Color(0xFF3A2E14),
    onWarning: Color(0xFFF2CC85),
    // SPEC_DEVIATION: no dedicated dark-mode row for warningInline either;
    // reusing onWarning's dark value for the same reason as textDisabled above.
    warningInline: Color(0xFFF2CC85),
    dangerBg: Color(0xFF3D1D1A),
    onDanger: Color(0xFFFFB4A8),
    dangerSolid: Color(0xFFB3261E),
    toastBg: Color(0xFFEDEDEA),
    onToast: Color(0xFF121413),
    scrim: Color(0x73141412),
    switchOff: Color(0xFF4A4F4C),
  );

  @override
  CantaeColors copyWith({
    Color? bg,
    Color? surface,
    Color? fillField,
    Color? fillMuted,
    Color? fillSecondary,
    Color? fillOnSurface,
    Color? divider,
    Color? segmentSelected,
    Color? text,
    Color? textBody,
    Color? text2,
    Color? text3,
    Color? textDisabled,
    Color? accent,
    Color? onAccent,
    Color? accentSoft,
    Color? onAccentSoft,
    Color? accentTrack,
    Color? warningBg,
    Color? onWarning,
    Color? warningInline,
    Color? dangerBg,
    Color? onDanger,
    Color? dangerSolid,
    Color? toastBg,
    Color? onToast,
    Color? scrim,
    Color? switchOff,
  }) {
    return CantaeColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      fillField: fillField ?? this.fillField,
      fillMuted: fillMuted ?? this.fillMuted,
      fillSecondary: fillSecondary ?? this.fillSecondary,
      fillOnSurface: fillOnSurface ?? this.fillOnSurface,
      divider: divider ?? this.divider,
      segmentSelected: segmentSelected ?? this.segmentSelected,
      text: text ?? this.text,
      textBody: textBody ?? this.textBody,
      text2: text2 ?? this.text2,
      text3: text3 ?? this.text3,
      textDisabled: textDisabled ?? this.textDisabled,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccentSoft: onAccentSoft ?? this.onAccentSoft,
      accentTrack: accentTrack ?? this.accentTrack,
      warningBg: warningBg ?? this.warningBg,
      onWarning: onWarning ?? this.onWarning,
      warningInline: warningInline ?? this.warningInline,
      dangerBg: dangerBg ?? this.dangerBg,
      onDanger: onDanger ?? this.onDanger,
      dangerSolid: dangerSolid ?? this.dangerSolid,
      toastBg: toastBg ?? this.toastBg,
      onToast: onToast ?? this.onToast,
      scrim: scrim ?? this.scrim,
      switchOff: switchOff ?? this.switchOff,
    );
  }

  @override
  CantaeColors lerp(ThemeExtension<CantaeColors>? other, double t) {
    if (other is! CantaeColors) {
      return this;
    }
    return CantaeColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      fillField: Color.lerp(fillField, other.fillField, t)!,
      fillMuted: Color.lerp(fillMuted, other.fillMuted, t)!,
      fillSecondary: Color.lerp(fillSecondary, other.fillSecondary, t)!,
      fillOnSurface: Color.lerp(fillOnSurface, other.fillOnSurface, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      segmentSelected: Color.lerp(segmentSelected, other.segmentSelected, t)!,
      text: Color.lerp(text, other.text, t)!,
      textBody: Color.lerp(textBody, other.textBody, t)!,
      text2: Color.lerp(text2, other.text2, t)!,
      text3: Color.lerp(text3, other.text3, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      onAccentSoft: Color.lerp(onAccentSoft, other.onAccentSoft, t)!,
      accentTrack: Color.lerp(accentTrack, other.accentTrack, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningInline: Color.lerp(warningInline, other.warningInline, t)!,
      dangerBg: Color.lerp(dangerBg, other.dangerBg, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
      dangerSolid: Color.lerp(dangerSolid, other.dangerSolid, t)!,
      toastBg: Color.lerp(toastBg, other.toastBg, t)!,
      onToast: Color.lerp(onToast, other.onToast, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      switchOff: Color.lerp(switchOff, other.switchOff, t)!,
    );
  }
}
