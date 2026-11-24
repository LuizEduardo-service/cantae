import 'package:flutter/material.dart';

import '../../domain/entities/naipe.dart';
import '../providers/lyrics_editor_notifier.dart';
import '../theme/cantae_colors.dart';
import '../theme/cantae_spacing.dart';
import '../theme/cantae_typography.dart';
import 'segmented_control.dart';
import 'track_align_row.dart' show TrackAlignDuration;
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

/// Naipe options: the badge letters, read out by full name. Full names do
/// not fit five segments on a 360 dp phone.
const List<SegmentedOption<Naipe?>> _naipeOptions = [
  SegmentedOption(label: 'S', value: Naipe.soprano, semanticLabel: 'Soprano'),
  SegmentedOption(
    label: 'C',
    value: Naipe.contralto,
    semanticLabel: 'Contralto',
  ),
  SegmentedOption(label: 'T', value: Naipe.tenor, semanticLabel: 'Tenor'),
  SegmentedOption(label: 'B', value: Naipe.bass, semanticLabel: 'Baixo'),
  SegmentedOption(label: '—', value: null, semanticLabel: 'Nenhum'),
];

/// One line in the lyrics editor: collapsed (tempo, texto, selo + dinâmica,
/// "Editar") or expanded inline (texto, naipe, dinâmica). Invalid text or
/// dinâmica reverts on blur instead of showing a modal error, like
/// [TrackAlignRow]'s offset field. See `docs/design/COMPONENTS.md`.
///
/// SPEC_DEVIATION: design.md's interface takes a `LyricLine`; this takes a
/// [LyricDraftLine], because a just-added line has empty text and
/// `LyricLine` rejects that (T5 decision "rascunho na tela").
class LyricLineRow extends StatefulWidget {
  const LyricLineRow({
    super.key,
    required this.line,
    required this.isCurrent,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onTextChanged,
    required this.onNaipeChanged,
    required this.onDynamicsChanged,
  });

  final LyricDraftLine line;
  final bool isCurrent;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<Naipe?> onNaipeChanged;
  final ValueChanged<String?> onDynamicsChanged;

  @override
  State<LyricLineRow> createState() => _LyricLineRowState();
}

class _LyricLineRowState extends State<LyricLineRow> {
  late final TextEditingController _textController;
  late final TextEditingController _dynamicsController;
  late final FocusNode _textFocus;
  late final FocusNode _dynamicsFocus;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.line.text);
    _dynamicsController =
        TextEditingController(text: widget.line.dynamics ?? '');
    _textFocus = FocusNode()..addListener(_onTextFocusChange);
    _dynamicsFocus = FocusNode()..addListener(_onDynamicsFocusChange);
  }

  @override
  void didUpdateWidget(LyricLineRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.line.text != widget.line.text &&
        _textController.text != widget.line.text) {
      _textController.text = widget.line.text;
    }
    final dynamics = widget.line.dynamics ?? '';
    if (oldWidget.line.dynamics != widget.line.dynamics &&
        _dynamicsController.text != dynamics) {
      _dynamicsController.text = dynamics;
    }
  }

  @override
  void dispose() {
    _textFocus
      ..removeListener(_onTextFocusChange)
      ..dispose();
    _dynamicsFocus
      ..removeListener(_onDynamicsFocusChange)
      ..dispose();
    _textController.dispose();
    _dynamicsController.dispose();
    super.dispose();
  }

  static bool _isValidText(String text) =>
      text.isNotEmpty && text.length <= lyricTextMaxLength;

  static bool _isValidDynamics(String text) =>
      text.length <= lyricDynamicsMaxLength;

  void _onTextFocusChange() {
    if (!_textFocus.hasFocus && !_isValidText(_textController.text)) {
      _textController.text = widget.line.text;
    }
  }

  void _onDynamicsFocusChange() {
    if (!_dynamicsFocus.hasFocus &&
        !_isValidDynamics(_dynamicsController.text)) {
      _dynamicsController.text = widget.line.dynamics ?? '';
    }
  }

  void _handleTextChanged(String value) {
    if (_isValidText(value)) widget.onTextChanged(value);
  }

  void _handleDynamicsChanged(String value) {
    if (!_isValidDynamics(value)) return;
    widget.onDynamicsChanged(value.isEmpty ? null : value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;

    return Semantics(
      container: true,
      label: widget.isCurrent ? 'Linha atual' : null,
      child: Container(
        key: const ValueKey('lyric-line-card'),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(CantaeRadii.radiusMd),
          border: Border.all(
            color: widget.isCurrent ? colors.accent : colors.divider,
            width: widget.isCurrent ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(CantaeSpacing.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              line: widget.line,
              isCurrent: widget.isCurrent,
              expanded: widget.expanded,
              onToggleExpanded: widget.onToggleExpanded,
            ),
            if (widget.expanded) ...[
              const SizedBox(height: CantaeSpacing.space3),
              _Field(
                controller: _textController,
                focusNode: _textFocus,
                hint: 'Texto da linha',
                onChanged: _handleTextChanged,
              ),
              const SizedBox(height: CantaeSpacing.space3),
              Text(
                'Naipe',
                style: CantaeTypography.caption.copyWith(color: colors.text2),
              ),
              const SizedBox(height: CantaeSpacing.space1),
              SegmentedControl<Naipe?>(
                options: _naipeOptions,
                selected: widget.line.naipe,
                onChanged: widget.onNaipeChanged,
              ),
              const SizedBox(height: CantaeSpacing.space3),
              _Field(
                controller: _dynamicsController,
                focusNode: _dynamicsFocus,
                hint: 'Dinâmica (opcional)',
                onChanged: _handleDynamicsChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.line,
    required this.isCurrent,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final LyricDraftLine line;
  final bool isCurrent;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final onsetMs = line.onsetMs;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          onsetMs == null ? '—' : TrackAlignDuration.format(onsetMs),
          style: CantaeTypography.mono.copyWith(color: colors.text2),
        ),
        const SizedBox(width: CantaeSpacing.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (line.hasText)
                Text(
                  line.text,
                  style: (isCurrent
                          ? CantaeTypography.listTitle
                          : CantaeTypography.body)
                      .copyWith(color: colors.text),
                )
              else
                Text(
                  'Linha sem texto',
                  style: CantaeTypography.body.copyWith(color: colors.text3),
                ),
              _NaipeLine(naipe: line.naipe, dynamics: line.dynamics),
            ],
          ),
        ),
        const SizedBox(width: CantaeSpacing.space2),
        _EditButton(
          label: expanded ? 'Concluir' : 'Editar',
          onTap: onToggleExpanded,
        ),
      ],
    );
  }
}

/// Selo + "Naipe · dinâmica" (spec P2 AC6): selo alone when there is no
/// dinâmica; dinâmica alone when there is no naipe.
class _NaipeLine extends StatelessWidget {
  const _NaipeLine({required this.naipe, required this.dynamics});

  final Naipe? naipe;
  final String? dynamics;

  @override
  Widget build(BuildContext context) {
    final naipe = this.naipe;
    final dynamics = this.dynamics;
    if (naipe == null && dynamics == null) return const SizedBox.shrink();

    final colors = Theme.of(context).extension<CantaeColors>()!;
    final style = CantaeTypography.caption.copyWith(color: colors.text2);

    return Padding(
      padding: const EdgeInsets.only(top: CantaeSpacing.space1),
      child: Row(
        children: [
          if (naipe != null)
            VoicePartBadge(
              variant: VoicePartBadgeVariant.filled,
              part: _voicePartFor(naipe),
              size: 18,
            ),
          if (naipe != null && dynamics != null)
            const SizedBox(width: CantaeSpacing.space1),
          if (dynamics != null)
            Flexible(
              child: Text(
                naipe == null ? dynamics : '${_naipeName(naipe)} · $dynamics',
                style: style,
              ),
            ),
        ],
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;

    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CantaeRadii.radiusXs),
        child: Container(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: CantaeSpacing.space2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.fillField,
            borderRadius: BorderRadius.circular(CantaeRadii.radiusXs),
          ),
          child: Text(
            label,
            style: CantaeTypography.label.copyWith(color: colors.text),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final radius = BorderRadius.circular(CantaeRadii.radiusSm);

    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      style: CantaeTypography.body.copyWith(color: colors.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: CantaeTypography.body.copyWith(color: colors.text3),
        filled: true,
        fillColor: colors.fillField,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: CantaeSpacing.space3,
          vertical: CantaeSpacing.space3,
        ),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: colors.accent, width: 2),
        ),
      ),
    );
  }
}
