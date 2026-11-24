import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/song.dart';
import '../../providers/lyrics_editor_notifier.dart';
import '../../theme/cantae_colors.dart';
import '../../theme/cantae_spacing.dart';
import '../../theme/cantae_typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/cantae_scaffold.dart';
import '../../widgets/confirm_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/inline_banner.dart';
import '../../widgets/lyric_line_row.dart';
import '../../widgets/nav_pill.dart';
import '../../widgets/toast.dart';
import '../../widgets/track_align_row.dart' show TrackAlignDuration;

/// Everything the screen renders except the playback clock. Watching this
/// (instead of the whole state) keeps position ticks from rebuilding the
/// line list; only the footer clock listens to `currentPositionMs`.
typedef _View = ({
  LyricsEditorStatus status,
  Song? song,
  List<LyricDraftLine> lines,
  int? expandedIndex,
  bool previewing,
  bool playing,
  int? currentLineIndex,
  int markedCount,
  int? nextUnmarkedIndex,
  String? markError,
  String? previewError,
  bool saving,
  String? saveError,
});

_View _viewOf(LyricsEditorState s) => (
      status: s.status,
      song: s.song,
      lines: s.lines,
      expandedIndex: s.expandedIndex,
      previewing: s.previewing,
      playing: s.playing,
      currentLineIndex: s.previewing ? s.currentLineIndex : null,
      markedCount: s.markedCount,
      nextUnmarkedIndex: s.nextUnmarkedIndex,
      markError: s.markError,
      previewError: s.previewError,
      saving: s.saving,
      saveError: s.saveError,
    );

/// `lyrics-editor` — `UI_SPEC.md` §6.6. All states live in this one file
/// (same precedent as `TrackAlignScreen`).
class LyricsEditorScreen extends ConsumerWidget {
  const LyricsEditorScreen({super.key, required this.songId});

  final String songId;

  Future<void> _handleBack(BuildContext context, WidgetRef ref) async {
    final state = ref.read(lyricsEditorProvider(songId));
    if (state.hasUnsavedChanges) {
      final confirmed = await ConfirmSheet.show(
        context,
        title: 'Descartar alterações?',
        message: 'A letra editada ainda não foi salva.',
        safeLabel: 'Continuar editando',
        destructiveLabel: 'Descartar alterações',
      );
      if (!confirmed) return;
    }
    if (context.mounted) {
      context.goNamed('song-detail', pathParameters: {'id': songId});
    }
  }

  Future<void> _handleSave(BuildContext context, WidgetRef ref) async {
    await ref.read(lyricsEditorProvider(songId).notifier).save();
    if (!context.mounted) return;
    if (ref.read(lyricsEditorProvider(songId)).saveError == null) {
      Toast.show(context, 'Letra salva');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(lyricsEditorProvider(songId).select(_viewOf));
    final notifier = ref.read(lyricsEditorProvider(songId).notifier);
    final backLabel = view.song?.name ?? 'Voltar';

    switch (view.status) {
      case LyricsEditorStatus.loading:
        return _StateScaffold(
          backLabel: backLabel,
          onBack: () => _handleBack(context, ref),
          body: const _LoadingBody(),
        );
      case LyricsEditorStatus.notFound:
        return _StateScaffold(
          backLabel: 'Biblioteca',
          onBack: () => context.goNamed('library'),
          body: const _NotFoundBody(),
        );
      case LyricsEditorStatus.error:
        return _StateScaffold(
          backLabel: backLabel,
          onBack: () => _handleBack(context, ref),
          body: _ErrorBody(onRetry: notifier.retry),
        );
      case LyricsEditorStatus.loaded:
        return _LoadedScaffold(
          songId: songId,
          view: view,
          notifier: notifier,
          onBack: () => _handleBack(context, ref),
          onSave: () => _handleSave(context, ref),
        );
    }
  }
}

class _StateScaffold extends StatelessWidget {
  const _StateScaffold({
    required this.backLabel,
    required this.onBack,
    required this.body,
  });

  final String backLabel;
  final VoidCallback onBack;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return CantaeScaffold(
      topLeft: NavPill(
        variant: NavPillVariant.back,
        label: backLabel,
        onTap: onBack,
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
      message:
          'Essa música não existe mais ou nunca existiu na sua biblioteca.',
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
        title: 'Não foi possível abrir a letra',
        message: 'A música não pôde ser lida neste aparelho. Tente de novo.',
        actionLabel: 'Tentar de novo',
        onAction: onRetry,
      ),
    );
  }
}

class _LoadedScaffold extends StatelessWidget {
  const _LoadedScaffold({
    required this.songId,
    required this.view,
    required this.notifier,
    required this.onBack,
    required this.onSave,
  });

  final String songId;
  final _View view;
  final LyricsEditorNotifier notifier;
  final VoidCallback onBack;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final song = view.song!;
    final hasTracks = song.tracks.isNotEmpty;

    return CantaeScaffold(
      topLeft: NavPill(
        variant: NavPillVariant.back,
        label: song.name,
        onTap: onBack,
      ),
      topRight: NavPill(
        variant: NavPillVariant.action,
        label: view.previewing ? 'Parar de ouvir' : 'Ouvir com a letra',
        onTap: hasTracks ? notifier.togglePreview : null,
      ),
      body: ListView(
        children: [
          const SizedBox(height: CantaeSpacing.space4),
          _Header(marked: view.markedCount, total: view.lines.length),
          const SizedBox(height: CantaeSpacing.space4),
          if (!hasTracks) ...[
            InlineBanner(
              variant: InlineBannerVariant.warning,
              title: 'Sem faixas para ouvir',
              message: 'Cadastre e alinhe as faixas desta música para marcar '
                  'os tempos. Você já pode digitar a letra.',
              actionLabel: 'Alinhar faixas',
              onAction: () => context.goNamed(
                'track-align',
                pathParameters: {'id': songId},
              ),
            ),
            const SizedBox(height: CantaeSpacing.space3),
          ],
          if (view.previewError != null) ...[
            InlineBanner(
              variant: InlineBannerVariant.error,
              title: 'Não foi possível ouvir',
              message: view.previewError!,
            ),
            const SizedBox(height: CantaeSpacing.space3),
          ],
          if (view.saveError != null) ...[
            InlineBanner(
              variant: InlineBannerVariant.error,
              title: 'Não foi possível salvar',
              message: view.saveError!,
            ),
            const SizedBox(height: CantaeSpacing.space3),
          ],
          if (view.lines.isEmpty)
            EmptyState(
              icon: Icons.subject,
              title: 'Nenhuma linha ainda',
              message: 'Acrescente as linhas da letra para marcar o tempo de '
                  'cada uma.',
              primaryLabel: 'Acrescentar linha',
              onPrimary: notifier.addLine,
            )
          else ...[
            for (var i = 0; i < view.lines.length; i++) ...[
              LyricLineRow(
                key: ValueKey('lyric-line-$i'),
                line: view.lines[i],
                isCurrent: view.currentLineIndex == i,
                expanded: view.expandedIndex == i,
                onToggleExpanded: () =>
                    notifier.setExpanded(view.expandedIndex == i ? null : i),
                onTextChanged: (text) => notifier.updateText(i, text),
                onNaipeChanged: (naipe) => notifier.updateNaipe(i, naipe),
                onDynamicsChanged: (value) => notifier.updateDynamics(i, value),
              ),
              const SizedBox(height: CantaeSpacing.space2),
            ],
            _AddLineButton(onTap: notifier.addLine),
          ],
          const SizedBox(height: CantaeSpacing.space4),
        ],
      ),
      footer: _footer(),
    );
  }

  /// No footer with no lines (spec AC13: the empty state's "Acrescentar
  /// linha" is the only primary action then).
  Widget? _footer() {
    if (view.lines.isEmpty) return null;
    if (!view.previewing) {
      return PrimaryButton(
        label: 'Salvar letra',
        loading: view.saving,
        onPressed: onSave,
      );
    }
    return _MarkingFooter(
      songId: songId,
      view: view,
      notifier: notifier,
      onSave: onSave,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.marked, required this.total});

  final int marked;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final mono = CantaeTypography.mono.copyWith(color: colors.text2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Letra',
          style: CantaeTypography.titlePage.copyWith(color: colors.text),
        ),
        const SizedBox(height: CantaeSpacing.space1),
        Semantics(
          container: true,
          liveRegion: true,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$marked', style: mono),
                const TextSpan(text: ' de '),
                TextSpan(text: '$total', style: mono),
                const TextSpan(text: ' marcadas'),
              ],
            ),
            style: CantaeTypography.bodySmall.copyWith(color: colors.text2),
          ),
        ),
      ],
    );
  }
}

class _AddLineButton extends StatelessWidget {
  const _AddLineButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;

    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CantaeRadii.radiusMd),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              Icon(Icons.add, color: colors.text),
              const SizedBox(width: CantaeSpacing.space2),
              Text(
                'Acrescentar linha',
                style: CantaeTypography.label.copyWith(color: colors.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Footer while marking: next-line card with the live clock, "Marcar agora"
/// as the one primary action, then Pausar/Continuar and Salvar.
class _MarkingFooter extends StatelessWidget {
  const _MarkingFooter({
    required this.songId,
    required this.view,
    required this.notifier,
    required this.onSave,
  });

  final String songId;
  final _View view;
  final LyricsEditorNotifier notifier;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final next = view.nextUnmarkedIndex;
    final canMark = view.playing && next != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NextCard(
          songId: songId,
          nextLine: next == null ? null : view.lines[next],
        ),
        if (view.markError != null) ...[
          const SizedBox(height: CantaeSpacing.space2),
          Semantics(
            liveRegion: true,
            child: InlineBanner(
              variant: InlineBannerVariant.error,
              title: 'Marcação recusada',
              message: view.markError!,
            ),
          ),
        ],
        const SizedBox(height: CantaeSpacing.space3),
        PrimaryButton(
          label: 'Marcar agora',
          onPressed: canMark ? notifier.markNow : null,
        ),
        const SizedBox(height: CantaeSpacing.space3),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: view.playing ? 'Pausar' : 'Continuar',
                onPressed: notifier.togglePause,
              ),
            ),
            const SizedBox(width: CantaeSpacing.space3),
            Expanded(
              child: SecondaryButton(
                label: 'Salvar letra',
                onPressed: view.saving ? null : onSave,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "Próxima: <texto>" + the current playback time. The only widget that
/// rebuilds on every position tick.
class _NextCard extends StatelessWidget {
  const _NextCard({required this.songId, required this.nextLine});

  final String songId;
  final LyricDraftLine? nextLine;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final line = nextLine;
    final label = line == null
        ? 'Todas as linhas marcadas'
        : 'Próxima: ${line.hasText ? line.text : 'Linha sem texto'}';

    return Container(
      padding: const EdgeInsets.all(CantaeSpacing.space3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(CantaeRadii.radiusMd),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: CantaeTypography.body.copyWith(color: colors.text),
            ),
          ),
          const SizedBox(width: CantaeSpacing.space2),
          Consumer(
            builder: (context, ref, _) {
              final positionMs = ref.watch(
                lyricsEditorProvider(songId).select((s) => s.currentPositionMs),
              );
              return Text(
                TrackAlignDuration.format(positionMs),
                style: CantaeTypography.mono.copyWith(color: colors.text2),
              );
            },
          ),
        ],
      ),
    );
  }
}
