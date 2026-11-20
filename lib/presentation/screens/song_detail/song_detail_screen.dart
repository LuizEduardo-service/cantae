import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/core/failures.dart';
import '../../../domain/entities/naipe.dart';
import '../../../domain/entities/song.dart';
import '../../../domain/entities/song_origin.dart';
import '../../providers/library_providers.dart';
import '../../providers/song_detail_providers.dart';
import '../../providers/song_repository_provider.dart';
import '../../theme/cantae_colors.dart';
import '../../theme/cantae_spacing.dart';
import '../../theme/cantae_typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/cantae_scaffold.dart';
import '../../widgets/confirm_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/inline_banner.dart';
import '../../widgets/nav_pill.dart';
import '../../widgets/voice_part_badge.dart';

const List<Naipe> _standardNaipes = [
  Naipe.soprano,
  Naipe.contralto,
  Naipe.tenor,
  Naipe.bass,
];

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

/// Hub for one música — `UI_SPEC.md` §6.3. All states/modes live in this one
/// file (same precedent as `library-screen`'s `LibraryScreen`).
class SongDetailScreen extends ConsumerStatefulWidget {
  const SongDetailScreen({super.key, required this.songId});

  final String songId;

  @override
  ConsumerState<SongDetailScreen> createState() => _SongDetailScreenState();
}

class _SongDetailScreenState extends ConsumerState<SongDetailScreen> {
  String? _deleteError;

  Future<void> _handleDelete(BuildContext context, Song song) async {
    final confirmed = await ConfirmSheet.show(
      context,
      title: 'Apagar música',
      message: 'Essa ação não pode ser desfeita.',
      safeLabel: 'Cancelar',
      destructiveLabel: 'Apagar definitivamente',
    );
    if (!confirmed) return;

    final repository = ref.read(songRepositoryProvider);
    final result = await repository.delete(song.id);
    result.when(
      success: (_) {
        ref.invalidate(songsProvider);
        if (context.mounted) context.goNamed('library');
      },
      failure: (_) {
        setState(() => _deleteError = 'Não foi possível apagar a música.');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final songAsync = ref.watch(songByIdProvider(widget.songId));

    return songAsync.when(
      loading: () => const _StateScaffold(body: _LoadingBody()),
      error: (_, __) => _StateScaffold(
        body: _ErrorBody(
          onRetry: () => ref.invalidate(songByIdProvider(widget.songId)),
        ),
      ),
      data: (result) => result.when(
        success: (song) => _HubScaffold(
          song: song,
          deleteError: _deleteError,
          onDelete: () => _handleDelete(context, song),
        ),
        failure: (failure) => _StateScaffold(
          body: failure is NotFoundFailure
              ? const _NotFoundBody()
              : _ErrorBody(
                  onRetry: () =>
                      ref.invalidate(songByIdProvider(widget.songId)),
                ),
        ),
      ),
    );
  }
}

/// Shared shell for the non-populated states (carregando / não encontrada /
/// erro): just a back `NavPill` and the body — no naipes, no rodapé.
class _StateScaffold extends StatelessWidget {
  const _StateScaffold({required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context) {
    return CantaeScaffold(
      topLeft: NavPill(
        variant: NavPillVariant.back,
        label: 'Biblioteca',
        onTap: () => context.goNamed('library'),
      ),
      body: body,
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    return Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(color: colors.accent),
      ),
    );
  }
}

class _NotFoundBody extends StatelessWidget {
  const _NotFoundBody();

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.search_off,
      title: 'Música não encontrada',
      message: 'Essa música não existe mais ou nunca existiu na sua biblioteca.',
      primaryLabel: 'Voltar à Biblioteca',
      onPrimary: () => context.goNamed('library'),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InlineBanner(
        variant: InlineBannerVariant.error,
        title: 'Não foi possível abrir a música',
        message: 'Verifique sua conexão com o armazenamento e tente de novo.',
        actionLabel: 'Tentar de novo',
        onAction: onRetry,
      ),
    );
  }
}

/// The populated hub — header, naipes, "Preparar" (hidden for `received`),
/// rodapé, and the exclusão flow.
class _HubScaffold extends StatelessWidget {
  const _HubScaffold({
    required this.song,
    required this.deleteError,
    required this.onDelete,
  });

  final Song song;
  final String? deleteError;
  final VoidCallback onDelete;

  Set<Naipe> get _coveredNaipes =>
      song.tracks.where((t) => !t.isPlayback).map((t) => t.naipe).toSet();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final covered = _coveredNaipes;
    final isReadOnly = song.origin == SongOrigin.received;

    return CantaeScaffold(
      topLeft: NavPill(
        variant: NavPillVariant.back,
        label: 'Biblioteca',
        onTap: () => context.goNamed('library'),
      ),
      topRight: NavPill(
        variant: NavPillVariant.action,
        label: 'Exportar',
        onTap: () => context.goNamed('package-import'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: CantaeSpacing.space4),
          Text(
            song.name,
            style: CantaeTypography.titlePage.copyWith(color: colors.text),
          ),
          const SizedBox(height: CantaeSpacing.space1),
          Text(
            '${song.author} · '
            '${isReadOnly ? 'Recebida' : 'Criada por você'}'
            '${song.isComplete ? '' : ' · Incompleta'}',
            style: CantaeTypography.bodySmall.copyWith(color: colors.text2),
          ),
          const SizedBox(height: CantaeSpacing.space6),
          const _SectionLabel('Naipes'),
          const SizedBox(height: CantaeSpacing.space2),
          for (final naipe in _standardNaipes)
            _NaipeRow(
              naipe: naipe,
              hasTrack: covered.contains(naipe),
              showUploadAction: !isReadOnly,
              onUpload: () => context.goNamed('track-upload'),
            ),
          if (!isReadOnly) ...[
            const SizedBox(height: CantaeSpacing.space6),
            const _SectionLabel('Preparar'),
            const SizedBox(height: CantaeSpacing.space2),
            _PreparaRow(
              label: 'Cortar áudio no Studio',
              onTap: () => context.goNamed('studio'),
            ),
            _PreparaRow(
              label: 'Alinhar entradas',
              onTap: () => context.goNamed('track-align'),
            ),
            _PreparaRow(
              label: song.lyrics.isEmpty
                  ? 'Sincronizar letra · Letra não sincronizada'
                  : 'Sincronizar letra · ${song.lyrics.length} linhas',
              onTap: () => context.goNamed('lyrics-editor'),
            ),
            _PreparaRow(
              label: 'Ensaios anteriores',
              onTap: () => context.goNamed('song-history'),
            ),
          ],
          const SizedBox(height: CantaeSpacing.space6),
          if (deleteError != null) ...[
            InlineBanner(
              variant: InlineBannerVariant.error,
              title: 'Não foi possível apagar',
              message: deleteError!,
            ),
            const SizedBox(height: CantaeSpacing.space3),
          ],
          DestructiveButton(label: 'Apagar desta música', onPressed: onDelete),
          const SizedBox(height: CantaeSpacing.space4),
        ],
      ),
      footer: Row(
        children: [
          Expanded(
            child: SecondaryButton(
              label: 'Ensaiar só',
              onPressed: () => context.goNamed('solo-player'),
            ),
          ),
          const SizedBox(width: CantaeSpacing.space3),
          Expanded(
            child: PrimaryButton(
              label: 'Ensaiar em grupo',
              onPressed: () => context.goNamed('room-create'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    return Text(
      label,
      style: CantaeTypography.caption.copyWith(color: colors.text2),
    );
  }
}

class _NaipeRow extends StatelessWidget {
  const _NaipeRow({
    required this.naipe,
    required this.hasTrack,
    required this.showUploadAction,
    required this.onUpload,
  });

  final Naipe naipe;
  final bool hasTrack;
  final bool showUploadAction;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CantaeSpacing.space2),
      child: Row(
        children: [
          VoicePartBadge(
            variant: hasTrack
                ? VoicePartBadgeVariant.filled
                : VoicePartBadgeVariant.missing,
            part: _voicePartFor(naipe),
          ),
          const SizedBox(width: CantaeSpacing.space3),
          Expanded(
            child: Text(
              _naipeName(naipe),
              style: CantaeTypography.body.copyWith(color: colors.text),
            ),
          ),
          if (!hasTrack && showUploadAction)
            Semantics(
              button: true,
              label: 'Enviar faixa de ${_naipeName(naipe)}',
              child: InkWell(
                onTap: onUpload,
                child: Text(
                  'Enviar faixa',
                  style: CantaeTypography.label.copyWith(color: colors.accent),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PreparaRow extends StatelessWidget {
  const _PreparaRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: CantaeSpacing.space3),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: CantaeTypography.body.copyWith(color: colors.text),
                ),
              ),
              Icon(Icons.chevron_right, color: colors.text2),
            ],
          ),
        ),
      ),
    );
  }
}
