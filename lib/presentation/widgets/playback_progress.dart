import 'package:flutter/material.dart';

import '../theme/cantae_colors.dart';
import '../theme/cantae_spacing.dart';
import '../theme/cantae_typography.dart';
import 'track_align_row.dart' show TrackAlignDuration;

/// Playback position bar (COMPONENTS.md `PlaybackProgress`): current and
/// total time in mono, an accent slider, the loop section painted in
/// `accentTrack`, and an optional caption ("Repetindo trecho 0:41–1:12").
///
/// While dragging, the shown time follows the finger and [onSeek] fires only
/// once, on release, so the audio engine is not flooded with seeks.
class PlaybackProgress extends StatefulWidget {
  const PlaybackProgress({
    super.key,
    required this.positionMs,
    required this.durationMs,
    required this.onSeek,
    this.loopStartMs,
    this.loopEndMs,
    this.caption,
  });

  final int positionMs;
  final int durationMs;
  final ValueChanged<int> onSeek;
  final int? loopStartMs;
  final int? loopEndMs;
  final String? caption;

  @override
  State<PlaybackProgress> createState() => _PlaybackProgressState();
}

class _PlaybackProgressState extends State<PlaybackProgress> {
  double? _dragMs;

  double get _maxMs => widget.durationMs > 0 ? widget.durationMs.toDouble() : 1;

  double? _fraction(int? ms) => ms == null ? null : (ms / _maxMs).clamp(0, 1);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final shownMs =
        (_dragMs ?? widget.positionMs.toDouble()).clamp(0.0, _maxMs);
    final hasLoop = widget.loopStartMs != null && widget.loopEndMs != null;
    final canSeek = widget.durationMs > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              TrackAlignDuration.format(shownMs.round()),
              style: CantaeTypography.mono.copyWith(color: colors.text),
            ),
            const Spacer(),
            Text(
              TrackAlignDuration.format(widget.durationMs),
              style: CantaeTypography.mono.copyWith(color: colors.text2),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            showValueIndicator: ShowValueIndicator.never,
            trackShape: PlaybackLoopTrackShape(
              loopStart: hasLoop ? _fraction(widget.loopStartMs) : null,
              loopEnd: hasLoop ? _fraction(widget.loopEndMs) : null,
              loopColor: colors.accentTrack,
            ),
          ),
          child: Slider(
            label: 'Posição da música',
            value: shownMs,
            max: _maxMs,
            activeColor: colors.accent,
            inactiveColor: colors.fillSecondary,
            semanticFormatterCallback: (value) =>
                TrackAlignDuration.format(value.round()),
            onChanged:
                canSeek ? (value) => setState(() => _dragMs = value) : null,
            onChangeEnd: canSeek
                ? (value) {
                    setState(() => _dragMs = null);
                    widget.onSeek(value.round());
                  }
                : null,
          ),
        ),
        if (widget.caption != null) ...[
          const SizedBox(height: CantaeSpacing.space1),
          Text(
            widget.caption!,
            style: CantaeTypography.caption.copyWith(color: colors.text2),
          ),
        ],
      ],
    );
  }
}

/// The slider's rounded track, plus the loop section drawn over it between
/// [loopStart] and [loopEnd] (fractions of the track, 0..1). Nothing extra
/// is drawn unless both are set.
class PlaybackLoopTrackShape extends RoundedRectSliderTrackShape {
  const PlaybackLoopTrackShape({
    required this.loopStart,
    required this.loopEnd,
    required this.loopColor,
  });

  final double? loopStart;
  final double? loopEnd;
  final Color loopColor;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
      additionalActiveTrackHeight: additionalActiveTrackHeight,
    );
    final start = loopStart;
    final end = loopEnd;
    if (start == null || end == null) return;

    final track = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final region = Rect.fromLTRB(
      track.left + track.width * start,
      track.top,
      track.left + track.width * end,
      track.bottom,
    );
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(region, Radius.circular(track.height / 2)),
      Paint()..color = loopColor,
    );
  }
}
