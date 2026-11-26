import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/naipe.dart';
import '../../../domain/entities/song_track.dart';
import '../../formatting/file_size_format.dart';
import '../../providers/song_editor_notifier.dart';
import '../../theme/cantae_colors.dart';
import '../../theme/cantae_spacing.dart';
import '../../theme/cantae_typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/cantae_scaffold.dart';
import '../../widgets/confirm_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/inline_banner.dart';
import '../../widgets/naipe_labels.dart';
import '../../widgets/nav_pill.dart';
import 'add_naipe_sheet.dart';

/// "Nova música" (no [songId]) or "Faixas" of an existing song —
/// `UI_SPEC.md` §6.4. [initialNaipe] opens the picker for that naipe once
/// the song is loaded ("Enviar faixa" in the Detalhe).
class SongEditorScreen extends ConsumerStatefulWidget {
  const SongEditorScreen({super.key, this.songId, this.initialNaipe});

  final String? songId;
  final Naipe? initialNaipe;

  @override
  ConsumerState<SongEditorScreen> createState() => _SongEditorScreenState();
}

class _SongEditorScreenState extends ConsumerState<SongEditorScreen> {
  final _name = TextEditingController();
  final _author = TextEditingController();
  bool _filled = false;
  bool _autoPicked = false;

  SongEditorNotifier get _notifier =>
      ref.read(songEditorProvider(widget.songId).notifier);

  @override
  void initState() {
    super.initState();
    ref.listenManual<SongEditorState>(
      songEditorProvider(widget.songId),
      (_, next) => _onState(next),
      fireImmediately: true,
    );
  }

  void _onState(SongEditorState state) {
    final loaded = state.status == SongEditorStatus.ready ||
        state.status == SongEditorStatus.readOnly;
    if (!loaded || _filled) return;
    _filled = true;
    _name.text = state.name;
    _author.text = state.author;
    final naipe = widget.initialNaipe;
    if (naipe != null &&
        !_autoPicked &&
        state.status == SongEditorStatus.ready) {
      _autoPicked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _notifier.pickFor(TrackSlot.standard(naipe));
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _author.dispose();
    super.dispose();
  }

  void _leave() {
    final songId = widget.songId;
    if (songId == null) {
      context.goNamed('library');
    } else {
      context.goNamed('song-detail', pathParameters: {'id': songId});
    }
  }

  Future<void> _back() async {
    final state = ref.read(songEditorProvider(widget.songId));
    if (state.isDirty) {
      final confirmed = await ConfirmSheet.show(
        context,
        title: 'Descartar alterações?',
        message: 'As mudanças nesta música ainda não foram salvas.',
        safeLabel: 'Continuar editando',
        destructiveLabel: 'Descartar alterações',
      );
      if (!confirmed) return;
    }
    if (mounted) _leave();
  }

  Future<void> _save() async {
    final id = await _notifier.save();
    if (id != null && mounted) {
      context.goNamed('song-detail', pathParameters: {'id': id});
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(songEditorProvider(widget.songId));
    final backLabel = widget.songId == null
        ? 'Biblioteca'
        : (state.songName.isEmpty ? 'Voltar' : state.songName);

    final Widget body;
    Widget? footer;
    switch (state.status) {
      case SongEditorStatus.loading:
        body = const _Loading();
      case SongEditorStatus.notFound:
        return CantaeScaffold(
          topLeft: NavPill(
            variant: NavPillVariant.back,
            label: 'Biblioteca',
            onTap: () => context.goNamed('library'),
          ),
          body: EmptyState(
            icon: Icons.search_off,
            title: 'Música não encontrada',
            message:
                'Essa música não existe mais ou nunca existiu na sua biblioteca.',
            primaryLabel: 'Voltar à Biblioteca',
            onPrimary: () => context.goNamed('library'),
          ),
        );
      case SongEditorStatus.error:
        body = Center(
          child: InlineBanner(
            variant: InlineBannerVariant.error,
            title: 'Não foi possível carregar a música',
            message: 'A música não pôde ser lida neste aparelho.',
            actionLabel: 'Tentar de novo',
            onAction: _notifier.retry,
          ),
        );
      case SongEditorStatus.readOnly:
      case SongEditorStatus.ready:
        final readOnly = state.status == SongEditorStatus.readOnly;
        body = _Form(
          songId: widget.songId,
          state: state,
          readOnly: readOnly,
          name: _name,
          author: _author,
          notifier: _notifier,
        );
        if (!readOnly) {
          footer = PrimaryButton(
            label: 'Salvar música',
            loading: state.saving,
            onPressed: state.canSave ? _save : null,
          );
        }
    }

    return PopScope(
      canPop: !state.isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: CantaeScaffold(
        topLeft: NavPill(
          variant: NavPillVariant.back,
          label: backLabel,
          onTap: _back,
        ),
        body: body,
        footer: footer,
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    return Center(child: CircularProgressIndicator(color: colors.accent));
  }
}

class _Form extends StatelessWidget {
  const _Form({
    required this.songId,
    required this.state,
    required this.readOnly,
    required this.name,
    required this.author,
    required this.notifier,
  });

  final String? songId;
  final SongEditorState state;
  final bool readOnly;
  final TextEditingController name;
  final TextEditingController author;
  final SongEditorNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final standard = state.slots
        .where((s) => !s.slot.isPlayback && s.slot.customNaipe == null);
    final playback = state.slots.where((s) => s.slot.isPlayback);
    final pickerError = state.pickerError;
    final saveError = state.saveError;

    _SlotRow row(TrackSlotState s) =>
        _SlotRow(slot: s, readOnly: readOnly, notifier: notifier);

    return ListView(
      children: [
        const SizedBox(height: CantaeSpacing.space4),
        Text(
          state.isNew ? 'Nova música' : 'Faixas',
          style: CantaeTypography.titlePage.copyWith(color: colors.text),
        ),
        const SizedBox(height: CantaeSpacing.space5),
        if (readOnly) ...[
          const InlineBanner(
            variant: InlineBannerVariant.info,
            title: 'Só leitura',
            message: 'Músicas recebidas de uma sala não podem ter as faixas '
                'trocadas.',
          ),
          const SizedBox(height: CantaeSpacing.space4),
        ],
        _Field(
          controller: name,
          label: 'Nome',
          error: state.nameError,
          enabled: !readOnly,
          onChanged: notifier.setName,
        ),
        const SizedBox(height: CantaeSpacing.space3),
        _Field(
          controller: author,
          label: 'Autor (opcional)',
          error: state.authorError,
          enabled: !readOnly,
          onChanged: notifier.setAuthor,
        ),
        if (pickerError != null) ...[
          const SizedBox(height: CantaeSpacing.space4),
          Semantics(
            liveRegion: true,
            child: InlineBanner(
              variant: InlineBannerVariant.error,
              title: 'Arquivos indisponíveis',
              message: pickerError,
            ),
          ),
        ],
        const SizedBox(height: CantaeSpacing.space6),
        const _SectionLabel('Naipes'),
        for (final s in standard) row(s),
        const SizedBox(height: CantaeSpacing.space5),
        const _SectionLabel('Playback'),
        for (final s in playback) row(s),
        const SizedBox(height: CantaeSpacing.space5),
        const _SectionLabel('Naipes extras'),
        for (final s in state.customSlots) row(s),
        if (!readOnly) ...[
          const SizedBox(height: CantaeSpacing.space2),
          SecondaryButton(
            label: 'Adicionar naipe',
            onPressed: state.canAddCustomNaipe
                ? () => AddNaipeSheet.show(context, songId: songId)
                : null,
          ),
          if (!state.canAddCustomNaipe) ...[
            const SizedBox(height: CantaeSpacing.space2),
            Text(
              'Até 4 naipes extras por música.',
              style: CantaeTypography.bodySmall.copyWith(color: colors.text2),
            ),
          ],
        ],
        if (saveError != null) ...[
          const SizedBox(height: CantaeSpacing.space4),
          Semantics(
            liveRegion: true,
            child: InlineBanner(
              variant: InlineBannerVariant.error,
              title: 'Música não salva',
              message: saveError,
            ),
          ),
        ],
        const SizedBox(height: CantaeSpacing.space4),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: CantaeSpacing.space1),
      child: Semantics(
        header: true,
        child: Text(
          label,
          style: CantaeTypography.caption.copyWith(color: colors.text2),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.error,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? error;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final radius = BorderRadius.circular(CantaeRadii.radiusSm);
    OutlineInputBorder border(Color? color) => OutlineInputBorder(
          borderRadius: radius,
          borderSide: color == null
              ? BorderSide.none
              : BorderSide(color: color, width: 2),
        );

    return TextField(
      controller: controller,
      enabled: enabled,
      onChanged: onChanged,
      textCapitalization: TextCapitalization.sentences,
      style: CantaeTypography.body.copyWith(color: colors.text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: CantaeTypography.body.copyWith(color: colors.text2),
        errorText: error,
        errorStyle:
            CantaeTypography.caption.copyWith(color: colors.dangerSolid),
        filled: true,
        fillColor: colors.fillField,
        border: border(null),
        enabledBorder: border(null),
        disabledBorder: border(null),
        focusedBorder: border(colors.accent),
        errorBorder: border(colors.dangerSolid),
        focusedErrorBorder: border(colors.dangerSolid),
      ),
    );
  }
}

String _slotKey(TrackSlotState s) {
  final custom = s.slot.customNaipe;
  if (custom != null) return 'custom-${custom.id}';
  if (s.slot.isPlayback) return 'playback';
  return s.slot.naipe.name;
}

String _slotName(TrackSlotState s) {
  if (s.slot.isPlayback) return 'Playback';
  return naipeLabel(s.slot.naipe, customNaipe: s.slot.customNaipe);
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.slot,
    required this.readOnly,
    required this.notifier,
  });

  final TrackSlotState slot;
  final bool readOnly;
  final SongEditorNotifier notifier;

  String get _statusText {
    if (slot.checking) return 'Conferindo arquivo…';
    final chosen = slot.chosen;
    if (chosen != null) {
      return '${chosen.name} · ${formatMegabytes(chosen.sizeBytes)}';
    }
    final saved = slot.removed ? null : slot.saved;
    if (saved == null) return 'Sem faixa';
    return _savedText(saved);
  }

  static String _savedText(SongTrack track) {
    final name = track.fileName;
    final size = track.fileSizeBytes;
    if (name == null) return 'Faixa salva';
    return size == null ? name : '$name · ${formatMegabytes(size)}';
  }

  Future<void> _replace(BuildContext context) async {
    if (slot.saved != null && slot.chosen == null && !slot.removed) {
      final confirmed = await ConfirmSheet.show(
        context,
        title: 'Trocar a faixa de ${_slotName(slot)}?',
        message: 'A faixa nova entra com atraso zero quando você salvar.',
        safeLabel: 'Cancelar',
        destructiveLabel: 'Trocar faixa',
      );
      if (!confirmed) return;
    }
    await notifier.pickFor(slot.slot);
  }

  Future<void> _remove(BuildContext context) async {
    if (slot.saved != null && slot.chosen == null) {
      final confirmed = await ConfirmSheet.show(
        context,
        title: 'Remover a faixa de ${_slotName(slot)}?',
        message: 'A faixa sai desta música quando você salvar.',
        safeLabel: 'Cancelar',
        destructiveLabel: 'Remover faixa',
      );
      if (!confirmed) return;
    }
    notifier.removeTrack(slot.slot);
  }

  Future<void> _dropCustom(BuildContext context) async {
    if (slot.saved != null && !slot.removed) {
      final confirmed = await ConfirmSheet.show(
        context,
        title: 'Tirar ${_slotName(slot)} desta música?',
        message: 'A faixa deste naipe sai da música quando você salvar. '
            'O naipe continua disponível para outras músicas.',
        safeLabel: 'Cancelar',
        destructiveLabel: 'Tirar naipe',
      );
      if (!confirmed) return;
    }
    notifier.removeCustomSlot(slot.slot);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final key = _slotKey(slot);
    final name = _slotName(slot);
    final error = slot.error;
    final hasFile = slot.current != null;
    final isCustom = slot.slot.customNaipe != null;

    _RowAction action(String label, String semantic, VoidCallback onTap) =>
        _RowAction(
          key: ValueKey('action-$key-$label'),
          label: label,
          semanticLabel: semantic,
          onTap: slot.checking ? null : onTap,
        );

    return Padding(
      key: ValueKey('slot-$key'),
      padding: const EdgeInsets.symmetric(vertical: CantaeSpacing.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MergeSemantics(
            child: Row(
              children: [
                if (!slot.slot.isPlayback) ...[
                  NaipeBadge(
                    naipe: slot.slot.naipe,
                    customNaipe: slot.slot.customNaipe,
                    missing: !hasFile,
                  ),
                  const SizedBox(width: CantaeSpacing.space3),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slot.slot.isPlayback ? 'Playback (opcional)' : name,
                        style:
                            CantaeTypography.body.copyWith(color: colors.text),
                      ),
                      Text(
                        _statusText,
                        style: (hasFile && !slot.checking
                                ? CantaeTypography.mono
                                : CantaeTypography.bodySmall)
                            .copyWith(color: colors.text2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (error != null)
            Semantics(
              liveRegion: true,
              child: Text(
                error,
                style: CantaeTypography.bodySmall
                    .copyWith(color: colors.dangerSolid),
              ),
            ),
          if (!readOnly)
            Wrap(
              spacing: CantaeSpacing.space2,
              children: [
                if (!hasFile)
                  action('Escolher arquivo', 'Escolher arquivo de $name',
                      () => notifier.pickFor(slot.slot)),
                if (hasFile) ...[
                  action('Trocar', 'Trocar faixa de $name',
                      () => _replace(context)),
                  action('Remover', 'Remover faixa de $name',
                      () => _remove(context)),
                ],
                if (isCustom)
                  action('Tirar naipe', 'Tirar $name desta música',
                      () => _dropCustom(context)),
              ],
            ),
        ],
      ),
    );
  }
}

/// A text action inside a track row, at least 44 × 44 dp.
class _RowAction extends StatelessWidget {
  const _RowAction({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticLabel,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CantaeRadii.radiusSm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: CantaeSpacing.minTouchTarget,
            minWidth: CantaeSpacing.minTouchTarget,
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: CantaeSpacing.space2),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: CantaeTypography.label.copyWith(
                  color: onTap == null ? colors.textDisabled : colors.accent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
