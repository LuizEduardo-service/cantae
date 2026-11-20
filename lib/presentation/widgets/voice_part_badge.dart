import 'package:flutter/material.dart';

import '../theme/cantae_spacing.dart';
import '../theme/cantae_typography.dart';
import '../theme/voice_part_colors.dart';

export '../theme/voice_part_colors.dart' show VoicePart;

/// Rendering styles a [VoicePartBadge] can take, per
/// `docs/design/COMPONENTS.md`'s `VoicePartBadge`.
enum VoicePartBadgeVariant {
  /// Has a recorded track — solid fill in the naipe's own color.
  filled,

  /// No recorded track for this naipe — dashed outline, `text2`.
  missing,

  /// The Visitante role badge ("V").
  visitor,

  /// The "every naipe" badge ("Todos").
  all,
}

/// Naipe badge. Color is never the only signal — a letter (or "Todos"/"V")
/// is always rendered alongside it.
class VoicePartBadge extends StatelessWidget {
  const VoicePartBadge({
    super.key,
    required this.variant,
    this.part,
    this.size = 22,
  }) : assert(
         variant != VoicePartBadgeVariant.filled &&
                 variant != VoicePartBadgeVariant.missing ||
             part != null,
         'filled/missing badges need a part to pick the right letter',
       );

  final VoicePartBadgeVariant variant;

  /// Which of the four singable naipes this badge shows. Required for
  /// [VoicePartBadgeVariant.filled]/[VoicePartBadgeVariant.missing]; ignored
  /// for [VoicePartBadgeVariant.visitor]/[VoicePartBadgeVariant.all], which
  /// always show their own fixed glyph.
  final VoicePart? part;

  final double size;

  String get _glyph {
    switch (variant) {
      case VoicePartBadgeVariant.visitor:
        return 'V';
      case VoicePartBadgeVariant.all:
        return 'Todos';
      case VoicePartBadgeVariant.filled:
      case VoicePartBadgeVariant.missing:
        switch (part!) {
          case VoicePart.soprano:
            return 'S';
          case VoicePart.contralto:
            return 'C';
          case VoicePart.tenor:
            return 'T';
          case VoicePart.baixo:
            return 'B';
          case VoicePart.todos:
          case VoicePart.semFaixa:
          case VoicePart.visitante:
            return '';
        }
    }
  }

  VoicePart get _colorKey {
    switch (variant) {
      case VoicePartBadgeVariant.visitor:
        return VoicePart.visitante;
      case VoicePartBadgeVariant.all:
        return VoicePart.todos;
      case VoicePartBadgeVariant.missing:
        return VoicePart.semFaixa;
      case VoicePartBadgeVariant.filled:
        return part!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final colors = VoicePartColors.of(_colorKey, brightness);

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.outlined ? null : colors.background,
          borderRadius: BorderRadius.circular(CantaeRadii.radiusXs),
        ),
        child: Center(
          child: colors.outlined
              ? CustomPaint(
                  painter: _DashedRoundedBorderPainter(
                    color: colors.textColor,
                    radius: CantaeRadii.radiusXs,
                  ),
                  child: _glyphText(colors.textColor),
                )
              : _glyphText(colors.textColor),
        ),
      ),
    );
  }

  Widget _glyphText(Color color) {
    final style = CantaeTypography.mono.copyWith(
      color: color,
      fontSize: size >= 24 ? 13 : 11,
    );
    return Padding(
      padding: const EdgeInsets.all(CantaeSpacing.space1 / 2),
      child: Text(_glyph, style: style, textAlign: TextAlign.center),
    );
  }
}

/// Paints a dashed rounded-rect outline, matching DESIGN_SYSTEM §2.3's
/// "naipe sem faixa" / "visitante" treatment (1,5 px dashed outline).
class _DashedRoundedBorderPainter extends CustomPainter {
  const _DashedRoundedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const _dashLength = 3.0;
  static const _gapLength = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      while (distance < metric.length) {
        final segmentLength = draw ? _dashLength : _gapLength;
        final end = (distance + segmentLength).clamp(0.0, metric.length);
        if (draw) {
          canvas.drawPath(metric.extractPath(distance, end), paint);
        }
        distance = end;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
