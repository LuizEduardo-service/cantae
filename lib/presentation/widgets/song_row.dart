import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:flutter/material.dart';

import '../theme/cantae_colors.dart';
import '../theme/cantae_spacing.dart';
import '../theme/cantae_typography.dart';
import 'voice_part_badge.dart';

/// One library list row: title, "Autor · status" subtitle, up to 4
/// [VoicePartBadge]s, and an optional "destacado" (highlighted) background.
/// See `docs/design/COMPONENTS.md`'s `SongRow`.
class SongRow extends StatelessWidget {
  const SongRow({
    super.key,
    required this.song,
    this.highlighted = false,
    required this.onTap,
  });

  final Song song;
  final bool highlighted;
  final VoidCallback onTap;

  static const List<Naipe> _standardOrder = [
    Naipe.soprano,
    Naipe.contralto,
    Naipe.tenor,
    Naipe.bass,
  ];

  static String _naipeName(Naipe naipe) {
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

  static VoicePart _voicePartFor(Naipe naipe) {
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

  Set<Naipe> get _coveredNaipes =>
      song.tracks.where((t) => !t.isPlayback).map((t) => t.naipe).toSet();

  List<Naipe> get _missingNaipes {
    final covered = _coveredNaipes;
    return _standardOrder.where((n) => !covered.contains(n)).toList();
  }

  /// `null` when the song is complete (no status text is shown).
  String? get _statusText {
    if (song.isComplete) return null;
    final missing = _missingNaipes;
    if (missing.length == 1) return 'Falta ${_naipeName(missing.first)}';
    return 'Faltam ${missing.length} naipes';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final covered = _coveredNaipes;
    final status = _statusText;

    return Semantics(
      button: true,
      label: song.name,
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: highlighted ? colors.surface : null,
          padding: const EdgeInsets.symmetric(
            horizontal: CantaeSpacing.space4,
            vertical: CantaeSpacing.space3,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      song.name,
                      style: CantaeTypography.listTitle.copyWith(
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: CantaeSpacing.space1),
                    RichText(
                      text: TextSpan(
                        style: CantaeTypography.caption.copyWith(
                          color: colors.text2,
                          fontWeight: FontWeight.w400,
                        ),
                        children: [
                          TextSpan(text: song.author),
                          if (status != null) ...[
                            const TextSpan(text: ' · '),
                            TextSpan(
                              text: status,
                              style: CantaeTypography.caption.copyWith(
                                color: colors.warningInline,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: CantaeSpacing.space3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: _standardOrder.map((naipe) {
                  final present = covered.contains(naipe);
                  return Padding(
                    padding: const EdgeInsets.only(left: CantaeSpacing.space1),
                    child: VoicePartBadge(
                      variant: present
                          ? VoicePartBadgeVariant.filled
                          : VoicePartBadgeVariant.missing,
                      part: _voicePartFor(naipe),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
