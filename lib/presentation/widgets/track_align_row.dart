import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/entities/naipe.dart';
import '../theme/cantae_colors.dart';
import '../theme/cantae_spacing.dart';
import '../theme/cantae_typography.dart';
import 'mute_solo_toggle.dart';
import 'voice_part_badge.dart';

String _naipeName(Naipe naipe) {
  switch (naipe) {
    case Naipe.soprano:
      return 'Soprano';
    case Naipe.contralto:
      return 'Contralto';
    case Naipe.tenor:
      return 'Tenor';
    case Naipe.bass:
      return 'Baixo';
    case Naipe.custom:
      return '';
  }
}

VoicePart _voicePartFor(Naipe naipe) {
  switch (naipe) {
    case Naipe.soprano:
      return VoicePart.soprano;
    case Naipe.contralto:
      return VoicePart.contralto;
    case Naipe.tenor:
      return VoicePart.tenor;
    case Naipe.bass:
      return VoicePart.baixo;
    case Naipe.custom:
      return VoicePart.todos;
  }
}

/// `mm:ss.s` formatting shared by [TrackAlignRow]'s offset field.
abstract final class TrackAlignDuration {
  static final RegExp _pattern = RegExp(r'^(\d+):([0-5]\d)\.(\d)$');

  static String format(int ms) {
    final clamped = ms < 0 ? 0 : ms;
    final totalTenths = clamped ~/ 100;
    final minutes = totalTenths ~/ 600;
    final seconds = (totalTenths ~/ 10) % 60;
    final tenths = totalTenths % 10;
    return '$minutes:${seconds.toString().padLeft(2, '0')}.$tenths';
  }

  /// Returns the parsed milliseconds, or `null` if [text] doesn't match
  /// `mm:ss.s` or would parse to a negative value.
  static int? parse(String text) {
    final match = _pattern.firstMatch(text.trim());
    if (match == null) return null;
    final minutes = int.parse(match.group(1)!);
    final seconds = int.parse(match.group(2)!);
    final tenths = int.parse(match.group(3)!);
    return (minutes * 60 + seconds) * 1000 + tenths * 100;
  }
}

/// One naipe row in `track-align` — selo, nome, campo de atraso `mm:ss.s`,
/// botões M/S e uma forma de onda estilizada deslocada pelo atraso atual.
/// See `docs/design/COMPONENTS.md`'s `TrackAlignRow`.
///
/// SPEC_DEVIATION: tasks.md's T5 description says the waveform bars are
/// "determinísticas a partir do id da faixa", but design.md's own
/// constructor signature (reproduced here) never passes a track id — only
/// `naipe`. The waveform seed uses `naipe` instead; still deterministic and
/// stable per row, just keyed one level up from the exact field this task
/// described.
class TrackAlignRow extends StatefulWidget {
  const TrackAlignRow({
    super.key,
    required this.naipe,
    required this.startDelayMs,
    required this.muted,
    required this.solo,
    required this.onOffsetChanged,
    required this.onMuteChanged,
    required this.onSoloChanged,
  });

  final Naipe naipe;
  final int startDelayMs;
  final bool muted;
  final bool solo;
  final ValueChanged<int> onOffsetChanged;
  final ValueChanged<bool> onMuteChanged;
  final ValueChanged<bool> onSoloChanged;

  @override
  State<TrackAlignRow> createState() => _TrackAlignRowState();
}

class _TrackAlignRowState extends State<TrackAlignRow> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: TrackAlignDuration.format(widget.startDelayMs),
    );
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(TrackAlignRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startDelayMs != widget.startDelayMs) {
      final formatted = TrackAlignDuration.format(widget.startDelayMs);
      if (_controller.text != formatted) {
        _controller.text = formatted;
      }
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      _revertIfInvalid();
    }
  }

  void _revertIfInvalid() {
    if (TrackAlignDuration.parse(_controller.text) == null) {
      _controller.text = TrackAlignDuration.format(widget.startDelayMs);
    }
  }

  void _handleChanged(String value) {
    final ms = TrackAlignDuration.parse(value);
    if (ms != null && ms >= 0) {
      widget.onOffsetChanged(ms);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(CantaeRadii.radiusMd),
        border: Border.all(
          color: widget.solo ? colors.accent : colors.divider,
          width: widget.solo ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.all(CantaeSpacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              VoicePartBadge(
                variant: VoicePartBadgeVariant.filled,
                part: _voicePartFor(widget.naipe),
              ),
              const SizedBox(width: CantaeSpacing.space2),
              Expanded(
                child: Text(
                  _naipeName(widget.naipe),
                  style: CantaeTypography.body.copyWith(color: colors.text),
                ),
              ),
              SizedBox(
                width: 76,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textAlign: TextAlign.right,
                  onChanged: _handleChanged,
                  onSubmitted: (_) => _revertIfInvalid(),
                  style: CantaeTypography.mono.copyWith(color: colors.text),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(width: CantaeSpacing.space2),
              MuteSoloToggle(
                label: 'M',
                semanticLabel: 'Mudo',
                active: widget.muted,
                onTap: () => widget.onMuteChanged(!widget.muted),
              ),
              const SizedBox(width: CantaeSpacing.space1),
              MuteSoloToggle(
                label: 'S',
                semanticLabel: 'Solo',
                active: widget.solo,
                onTap: () => widget.onSoloChanged(!widget.solo),
              ),
            ],
          ),
          const SizedBox(height: CantaeSpacing.space2),
          Opacity(
            opacity: widget.muted ? 0.25 : 1.0,
            child: _Waveform(
              seed: widget.naipe.index,
              offsetMs: widget.startDelayMs,
              color: colors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// Stylized, non-decoded waveform — deterministic bars from [seed], shifted
/// right by [offsetMs] (spec.md's Out of Scope: never the real audio).
class _Waveform extends StatelessWidget {
  const _Waveform({
    required this.seed,
    required this.offsetMs,
    required this.color,
  });

  final int seed;
  final int offsetMs;
  final Color color;

  static const int _barCount = 24;
  static const double _barWidth = 3;
  static const double _gap = 2;
  static const double _height = 28;

  @override
  Widget build(BuildContext context) {
    final random = Random(seed);
    final bars = List.generate(
      _barCount,
      (_) => 0.25 + random.nextDouble() * 0.75,
    );
    final shiftPx = (offsetMs / 1000 * 6).clamp(0, 48).toDouble();

    return SizedBox(
      height: _height,
      child: Padding(
        padding: EdgeInsets.only(left: shiftPx),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final heightFraction in bars)
              Padding(
                padding: const EdgeInsets.only(right: _gap),
                child: Container(
                  width: _barWidth,
                  height: _height * heightFraction,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
