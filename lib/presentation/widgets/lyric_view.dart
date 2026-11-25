import 'package:flutter/material.dart';

import '../../domain/audio/lyric_cursor.dart';
import '../../domain/entities/lyric_line.dart';
import '../../domain/entities/naipe.dart';
import '../theme/cantae_colors.dart';
import '../theme/cantae_spacing.dart';
import '../theme/cantae_typography.dart';
import 'naipe_labels.dart';
import 'voice_part_badge.dart';

/// Compact synced lyrics (COMPONENTS.md `LyricView`): the line already
/// sung, the current line in a card, and the next one. Shared by Modo solo
/// and, later, the room screens.
///
/// [lines] holds only timed lines, in lyric order; [cursor] comes from
/// [LyricCursor.at]. [userVoicePart] is for the room's "Próxima é sua" and
/// is unused while null.
class LyricView extends StatelessWidget {
  const LyricView({
    super.key,
    required this.lines,
    required this.cursor,
    this.userVoicePart,
  });

  final List<LyricLine> lines;
  final LyricCursorResult cursor;
  final Naipe? userVoicePart;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final previous = cursor.previous;
    final current = cursor.current;
    final next = cursor.next;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (previous != null) ...[
          Text(
            lines[previous].text,
            style: CantaeTypography.lyricPast.copyWith(color: colors.text3),
          ),
          const SizedBox(height: CantaeSpacing.space3),
        ],
        if (current != null) ...[
          _ActiveLine(line: lines[current]),
          const SizedBox(height: CantaeSpacing.space3),
        ],
        if (next != null) ...[
          Text(
            'Próxima',
            style: CantaeTypography.caption.copyWith(color: colors.text2),
          ),
          const SizedBox(height: CantaeSpacing.space1),
          Text(
            lines[next].text,
            style: CantaeTypography.lyricNext.copyWith(color: colors.text),
          ),
        ],
      ],
    );
  }
}

class _ActiveLine extends StatelessWidget {
  const _ActiveLine({required this.line});

  final LyricLine line;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final naipe = line.naipe;
    final dynamics = line.dynamics;
    final String? detail;
    if (naipe != null && dynamics != null) {
      detail = '${naipeDisplayName(naipe)} · $dynamics';
    } else if (naipe != null) {
      detail = naipeDisplayName(naipe);
    } else {
      detail = dynamics;
    }

    return Semantics(
      liveRegion: true,
      label: 'Linha atual',
      child: Container(
        padding: const EdgeInsets.all(CantaeSpacing.space4),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(CantaeRadii.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (detail != null) ...[
              Row(
                children: [
                  if (naipe != null) ...[
                    VoicePartBadge(
                      variant: VoicePartBadgeVariant.filled,
                      part: voicePartForNaipe(naipe),
                    ),
                    const SizedBox(width: CantaeSpacing.space2),
                  ],
                  Flexible(
                    child: Text(
                      detail,
                      style: CantaeTypography.caption.copyWith(
                        color: colors.text2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CantaeSpacing.space2),
            ],
            Text(
              line.text,
              style: CantaeTypography.lyricActive.copyWith(color: colors.text),
            ),
          ],
        ),
      ),
    );
  }
}
