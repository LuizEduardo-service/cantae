import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/song.dart';
import '../../providers/library_providers.dart';
import '../../theme/cantae_colors.dart';
import '../../theme/cantae_spacing.dart';
import '../../theme/cantae_typography.dart';

/// What the master picked: a song, or none ("Sem música").
class SongChoice {
  final Song? song;

  const SongChoice(this.song);
}

/// "Escolher música" / "Trocar" on Criar sala (ROOM-09): the library's
/// songs with the current one marked, and "Sem música".
abstract final class SongChoiceSheet {
  /// Null when the sheet was closed without a choice.
  static Future<SongChoice?> show(BuildContext context, {String? currentId}) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    return showModalBottomSheet<SongChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: colors.scrim,
      builder: (_) => _SongChoiceBody(currentId: currentId),
    );
  }
}

class _SongChoiceBody extends ConsumerWidget {
  const _SongChoiceBody({required this.currentId});

  final String? currentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final songs = ref.watch(songsProvider);
    void choose(Song? song) => Navigator.of(context).pop(SongChoice(song));

    final List<Widget> rows = songs.when(
      loading: () => [
        const Padding(
          padding: EdgeInsets.all(CantaeSpacing.space5),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      error: (_, __) => [
        _Message('Não foi possível ler a biblioteca.', colors: colors),
      ],
      data: (list) => list.isEmpty
          ? [
              _Message(
                'Sua biblioteca ainda não tem músicas. A sala funciona sem '
                'música.',
                colors: colors,
              ),
            ]
          : [
              for (final song in list)
                _ChoiceRow(
                  title: song.name,
                  subtitle: song.author.isEmpty ? null : song.author,
                  selected: song.id == currentId,
                  onTap: () => choose(song),
                ),
            ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(CantaeRadii.radiusSheet),
        ),
      ),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(CantaeSpacing.space5),
            children: [
              Text(
                'Música da sala',
                style: CantaeTypography.titleSheet.copyWith(color: colors.text),
              ),
              const SizedBox(height: CantaeSpacing.space3),
              ...rows,
              _ChoiceRow(
                title: 'Sem música',
                selected: currentId == null,
                onTap: () => choose(null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    return Semantics(
      button: true,
      selected: selected,
      label: subtitle == null ? title : '$title, $subtitle',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(minHeight: CantaeSpacing.minTouchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: CantaeSpacing.space2),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style:
                            CantaeTypography.body.copyWith(color: colors.text),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: CantaeTypography.bodySmall
                              .copyWith(color: colors.text2),
                        ),
                    ],
                  ),
                ),
                if (selected) Icon(Icons.check, color: colors.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {required this.colors});

  final String text;
  final CantaeColors colors;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: CantaeSpacing.space3),
        child: Text(
          text,
          style: CantaeTypography.bodySmall.copyWith(color: colors.text2),
        ),
      );
}
