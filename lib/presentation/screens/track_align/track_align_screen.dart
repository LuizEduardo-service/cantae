import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/naipe.dart';
import '../../providers/track_align_notifier.dart';
import '../../theme/cantae_colors.dart';
import '../../theme/cantae_spacing.dart';
import '../../theme/cantae_typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/cantae_scaffold.dart';
import '../../widgets/confirm_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/inline_banner.dart';
import '../../widgets/nav_pill.dart';
import '../../widgets/toast.dart';
import '../../widgets/track_align_row.dart';

const List<Naipe> _standardNaipes = [
  Naipe.soprano,
  Naipe.contralto,
  Naipe.tenor,
  Naipe.bass,
];

/// `track-align` — `UI_SPEC.md` §6.5. All states live in this one file (same
/// precedent as `SongDetailScreen`/`LibraryScreen`).
class TrackAlignScreen extends ConsumerWidget {
  const TrackAlignScreen({super.key, required this.songId});

  final String songId;

  Future<void> _handleBack(
    BuildContext context,
    TrackAlignState state,
  ) async {
    if (state.hasUnsavedChanges) {
      final confirmed = await ConfirmSheet.show(
        context,
        title: 'Descartar alterações?',
        message: 'Os atrasos editados ainda não foram salvos.',
        safeLabel: 'Continuar editando',
        destructiveLabel: 'Descartar alterações',
      );
      if (!confirmed) return;
    }
    if (context.mounted) {
      context.goNamed('song-detail', pathParameters: {'id': songId});
    }
  }

  Future<void> _handleSave(
    BuildContext context,
    WidgetRef ref,
    TrackAlignNotifier notifier,
  ) async {
    await notifier.save();
    if (!context.mounted) return;
    final state = ref.read(trackAlignProvider(songId));
    if (state.saveError == null) {
      Toast.show(context, 'Atrasos salvos');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trackAlignProvider(songId));
    final notifier = ref.read(trackAlignProvider(songId).notifier);
    final backLabel = state.song?.name ?? 'Voltar';

    switch (state.status) {
      case TrackAlignStatus.loading:
        return _StateScaffold(
          backLabel: backLabel,
          onBack: () => _handleBack(context, state),
          body: const _LoadingBody(),
        );
      case TrackAlignStatus.notFound:
        return _StateScaffold(
          backLabel: 'Biblioteca',
          onBack: () => context.goNamed('library'),
          body: const _NotFoundBody(),
        );
      case TrackAlignStatus.noTracks:
        return _StateScaffold(
          backLabel: backLabel,
          onBack: () => _handleBack(context, state),
          body: _NoTracksBody(songId: songId),
        );
      case TrackAlignStatus.error:
        return _StateScaffold(
          backLabel: backLabel,
          onBack: () => _handleBack(context, state),
          body: _ErrorBody(onRetry: notifier.retry),
        );
      case TrackAlignStatus.loaded:
        return _LoadedScaffold(
          state: state,
          notifier: notifier,
          onBack: () => _handleBack(context, state),
          onSave: () => _handleSave(context, ref, notifier),
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

class _NoTracksBody extends StatelessWidget {
  const _NoTracksBody({required this.songId});

  final String songId;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.graphic_eq,
      title: 'Sem faixas',
      message: 'Grave ou envie pelo menos uma faixa antes de alinhar entradas.',
      primaryLabel: 'Cortar áudio no Studio',
      onPrimary: () => context.goNamed('studio'),
      secondaryLabel: 'Enviar faixa',
      onSecondary: () => context.goNamed(
        'track-upload',
        pathParameters: {'id': songId},
      ),
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
        title: 'Não foi possível carregar o áudio',
        message: 'Verifique os arquivos das faixas e tente de novo.',
        actionLabel: 'Tentar de novo',
        onAction: onRetry,
      ),
    );
  }
}

class _LoadedScaffold extends StatelessWidget {
  const _LoadedScaffold({
    required this.state,
    required this.notifier,
    required this.onBack,
    required this.onSave,
  });

  final TrackAlignState state;
  final TrackAlignNotifier notifier;
  final VoidCallback onBack;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final song = state.song!;
    // The 4 standard naipes in order, then the custom naipes (UPL-16).
    final rows = [
      for (final naipe in _standardNaipes)
        ...song.tracks.where((t) => t.naipe == naipe).take(1),
      ...song.tracks.where((t) => t.customNaipe != null),
    ];

    return CantaeScaffold(
      topLeft: NavPill(
        variant: NavPillVariant.back,
        label: song.name,
        onTap: onBack,
      ),
      body: ListView(
        children: [
          const SizedBox(height: CantaeSpacing.space4),
          Text(
            'Alinhar entradas',
            style: CantaeTypography.titlePage.copyWith(color: colors.text),
          ),
          const SizedBox(height: CantaeSpacing.space1),
          Text(
            'Ajuste o atraso de entrada de cada naipe e teste com mudo, solo e loop.',
            style: CantaeTypography.bodySmall.copyWith(color: colors.text2),
          ),
          const SizedBox(height: CantaeSpacing.space5),
          for (final track in rows) ...[
            TrackAlignRow(
              naipe: track.naipe,
              customNaipe: track.customNaipe,
              startDelayMs:
                  state.startDelayMsByTrackId[track.id] ?? track.startDelayMs,
              muted: state.mutedByTrackId[track.id] ?? false,
              solo: state.soloTrackId == track.id,
              onOffsetChanged: (ms) => notifier.setOffset(track.id, ms),
              onMuteChanged: (muted) => notifier.setMuted(track.id, muted),
              onSoloChanged: (solo) => notifier.setSolo(track.id, solo),
            ),
            const SizedBox(height: CantaeSpacing.space3),
          ],
          const SizedBox(height: CantaeSpacing.space3),
          Text(
            'Testar trecho',
            style: CantaeTypography.caption.copyWith(color: colors.text2),
          ),
          const SizedBox(height: CantaeSpacing.space2),
          Row(
            children: [
              Expanded(
                child: _LoopField(
                  label: 'Início',
                  valueMs: state.loopStartMs,
                  onChanged: notifier.setLoopStart,
                ),
              ),
              const SizedBox(width: CantaeSpacing.space3),
              Expanded(
                child: _LoopField(
                  label: 'Fim',
                  valueMs: state.loopEndMs,
                  onChanged: notifier.setLoopEnd,
                ),
              ),
            ],
          ),
          const SizedBox(height: CantaeSpacing.space4),
          if (state.saveError != null) ...[
            InlineBanner(
              variant: InlineBannerVariant.error,
              title: 'Não foi possível salvar',
              message: state.saveError!,
            ),
            const SizedBox(height: CantaeSpacing.space3),
          ],
          const SizedBox(height: CantaeSpacing.space4),
        ],
      ),
      footer: Row(
        children: [
          Expanded(
            child: SecondaryButton(
              label: state.testing ? 'Parar' : 'Ouvir em loop',
              onPressed: notifier.toggleTest,
            ),
          ),
          const SizedBox(width: CantaeSpacing.space3),
          Expanded(
            child: PrimaryButton(
              label: 'Salvar atrasos',
              loading: state.saving,
              onPressed: onSave,
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline `mm:ss.s` field for the loop region — screen-local, not shared
/// (unlike `TrackAlignRow`'s own offset field, this has no mudo/solo UI).
class _LoopField extends StatefulWidget {
  const _LoopField({
    required this.label,
    required this.valueMs,
    required this.onChanged,
  });

  final String label;
  final int valueMs;
  final ValueChanged<int> onChanged;

  @override
  State<_LoopField> createState() => _LoopFieldState();
}

class _LoopFieldState extends State<_LoopField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: TrackAlignDuration.format(widget.valueMs),
    );
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(_LoopField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.valueMs != widget.valueMs) {
      final formatted = TrackAlignDuration.format(widget.valueMs);
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
      _controller.text = TrackAlignDuration.format(widget.valueMs);
    }
  }

  void _handleChanged(String value) {
    final ms = TrackAlignDuration.parse(value);
    if (ms != null) {
      widget.onChanged(ms);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;

    return Container(
      decoration: BoxDecoration(
        color: colors.fillField,
        borderRadius: BorderRadius.circular(CantaeRadii.radiusSm),
      ),
      padding: const EdgeInsets.symmetric(horizontal: CantaeSpacing.space3),
      child: Row(
        children: [
          Text(
            widget.label,
            style: CantaeTypography.caption.copyWith(color: colors.text2),
          ),
          const SizedBox(width: CantaeSpacing.space2),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textAlign: TextAlign.right,
              onChanged: _handleChanged,
              style: CantaeTypography.mono.copyWith(color: colors.text),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
