import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/song.dart';
import '../../../domain/entities/song_origin.dart';
import '../../providers/library_providers.dart';
import '../../theme/cantae_colors.dart';
import '../../theme/cantae_spacing.dart';
import '../../theme/cantae_typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/cantae_scaffold.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/inline_banner.dart';
import '../../widgets/nav_pill.dart';
import '../../widgets/search_field.dart';
import '../../widgets/segmented_control.dart';
import '../../widgets/song_row.dart';

/// The Biblioteca (library) screen — the app's home screen. Covers all 5
/// states from `spec.md`'s P1 story: loading, populated, empty,
/// filtered-empty, error. See `docs/design/UI_SPEC.md` §6.2/§6.2b.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final songsAsync = ref.watch(songsProvider);

    return CantaeScaffold(
      topLeft: Text(
        'Biblioteca',
        style: CantaeTypography.titlePage.copyWith(color: colors.text),
      ),
      topRight: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NavPill(
            variant: NavPillVariant.action,
            label: 'Importar',
            onTap: () => context.goNamed('package-import'),
          ),
          const SizedBox(width: CantaeSpacing.space2),
          _AvatarButton(onTap: () => context.goNamed('profile')),
        ],
      ),
      body: songsAsync.when(
        loading: () => const _LoadingBody(),
        error: (error, stackTrace) =>
            _ErrorBody(onRetry: () => ref.invalidate(songsProvider)),
        data: (songs) {
          if (songs.isEmpty) {
            return _EmptyBody(
              onCreateSong: () => context.goNamed('song-create'),
              onOpenPackage: () => context.goNamed('package-import'),
              onJoinRoom: () => context.goNamed('room-join'),
            );
          }
          return const _PopulatedBody();
        },
      ),
      footer: songsAsync.maybeWhen(
        data: (songs) => songs.isEmpty ? null : _buildFooter(context),
        orElse: () => _buildFooter(context),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SecondaryButton(
            label: 'Entrar em sala',
            onPressed: () => context.goNamed('room-join'),
          ),
        ),
        const SizedBox(width: CantaeSpacing.space3),
        Expanded(
          child: PrimaryButton(
            label: 'Criar sala',
            onPressed: () => context.goNamed('room-create'),
          ),
        ),
      ],
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    return Semantics(
      button: true,
      label: 'Perfil',
      child: Material(
        color: colors.fillMuted,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.person_outline, color: colors.text),
          ),
        ),
      ),
    );
  }
}

void _noop(String _) {}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SearchField(enabled: false, onChanged: _noop),
        const SizedBox(height: CantaeSpacing.space4),
        Expanded(
          child: ListView.separated(
            itemCount: 5,
            separatorBuilder: (_, __) =>
                const SizedBox(height: CantaeSpacing.space2),
            itemBuilder: (context, index) => const _SkeletonRow(),
          ),
        ),
      ],
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: colors.fillMuted,
        borderRadius: BorderRadius.circular(CantaeRadii.radiusSm),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: CantaeSpacing.space4),
        child: InlineBanner(
          variant: InlineBannerVariant.error,
          title: 'Não foi possível carregar sua biblioteca',
          message: 'Verifique o armazenamento do aparelho e tente de novo.',
          actionLabel: 'Tentar de novo',
          onAction: onRetry,
        ),
      ),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({
    required this.onCreateSong,
    required this.onOpenPackage,
    required this.onJoinRoom,
  });

  final VoidCallback onCreateSong;
  final VoidCallback onOpenPackage;
  final VoidCallback onJoinRoom;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    return Column(
      children: [
        Expanded(
          child: EmptyState(
            icon: Icons.library_music_outlined,
            title: 'Nenhuma música ainda',
            message:
                'Cadastre sua primeira música ou importe um pacote .cantae '
                'para começar.',
            primaryLabel: 'Cadastrar primeira música',
            onPrimary: onCreateSong,
            secondaryLabel: 'Abrir pacote .cantae',
            onSecondary: onOpenPackage,
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(CantaeSpacing.space4),
          margin: const EdgeInsets.only(bottom: CantaeSpacing.space4),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(CantaeRadii.radiusLg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tem ensaio rolando por perto?',
                style: CantaeTypography.bodySmall.copyWith(
                  color: colors.textBody,
                ),
              ),
              const SizedBox(height: CantaeSpacing.space3),
              SecondaryButton(label: 'Entrar em sala', onPressed: onJoinRoom),
            ],
          ),
        ),
      ],
    );
  }
}

class _PopulatedBody extends ConsumerWidget {
  const _PopulatedBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final query = ref.watch(searchQueryProvider);
    final origin = ref.watch(originFilterProvider);
    final sortOrder = ref.watch(sortOrderProvider);
    final visible = ref.watch(visibleSongsProvider).value ?? const <Song>[];
    final highlightedId = ref.watch(highlightedSongIdProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SearchField(
          onChanged: (value) =>
              ref.read(searchQueryProvider.notifier).state = value,
        ),
        const SizedBox(height: CantaeSpacing.space3),
        SegmentedControl<SongOrigin?>(
          options: const [
            SegmentedOption(label: 'Todas', value: null),
            SegmentedOption(label: 'Criadas', value: SongOrigin.created),
            SegmentedOption(label: 'Recebidas', value: SongOrigin.received),
          ],
          selected: origin,
          onChanged: (value) =>
              ref.read(originFilterProvider.notifier).state = value,
        ),
        const SizedBox(height: CantaeSpacing.space3),
        Row(
          children: [
            Text(
              '${visible.length} músicas',
              style: CantaeTypography.caption.copyWith(color: colors.text2),
            ),
            const SizedBox(width: CantaeSpacing.space3),
            Expanded(
              child: SegmentedControl<LibrarySortOrder>(
                options: const [
                  SegmentedOption(
                    label: 'Nome (A-Z)',
                    value: LibrarySortOrder.name,
                  ),
                  SegmentedOption(
                    label: 'Último ensaio',
                    value: LibrarySortOrder.lastRehearsed,
                  ),
                ],
                selected: sortOrder,
                onChanged: (value) =>
                    ref.read(sortOrderProvider.notifier).state = value,
              ),
            ),
          ],
        ),
        const SizedBox(height: CantaeSpacing.space3),
        Expanded(
          child: visible.isEmpty
              ? _FilteredEmptyBody(
                  query: query,
                  onClear: () {
                    ref.read(searchQueryProvider.notifier).state = '';
                    ref.read(originFilterProvider.notifier).state = null;
                  },
                )
              : ListView.separated(
                  itemCount: visible.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: colors.divider),
                  itemBuilder: (context, index) {
                    final song = visible[index];
                    return SongRow(
                      song: song,
                      highlighted: song.id == highlightedId,
                      onTap: () => context.goNamed(
                        'song-detail',
                        pathParameters: {'id': song.id},
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FilteredEmptyBody extends StatelessWidget {
  const _FilteredEmptyBody({required this.query, required this.onClear});

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    // SPEC_DEVIATION: spec.md's AC only defines the exact copy for the
    // search-query case ("Nada encontrado para "{query}""). The
    // origin-filter-only case (e.g. "Recebidas" with no received songs) has
    // no defined copy — a spec-precision gap — so it falls back to the same
    // message without the quoted query.
    final message =
        query.isEmpty ? 'Nada encontrado' : 'Nada encontrado para "$query"';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: CantaeTypography.body.copyWith(color: colors.textBody),
          ),
          const SizedBox(height: CantaeSpacing.space3),
          Semantics(
            button: true,
            label: 'Limpar busca',
            child: InkWell(
              onTap: onClear,
              child: Text(
                'Limpar busca',
                style: CantaeTypography.label.copyWith(color: colors.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
