import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/metronome_config.dart';
import '../theme/cantae_colors.dart';
import '../theme/cantae_spacing.dart';
import '../theme/cantae_typography.dart';
import 'buttons.dart';
import 'inline_banner.dart';
import 'segmented_control.dart';

/// "Andamento" sheet (COMPONENTS.md `TempoSheet`): BPM, beats per measure
/// and downbeat accent for the metronome (RF50).
///
/// [onSave] returns null on success, which closes the sheet, or an error
/// message, which keeps the sheet open with the typed values.
abstract final class TempoSheet {
  static const int minBpm = 30;
  static const int maxBpm = 300;
  static const int minBeats = 2;
  static const int maxBeats = 16;

  static Future<void> show(
    BuildContext context, {
    required MetronomeConfig initial,
    required Future<String?> Function(MetronomeConfig config) onSave,
  }) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: colors.scrim,
      builder: (context) => _TempoSheetBody(initial: initial, onSave: onSave),
    );
  }
}

class _TempoSheetBody extends StatefulWidget {
  const _TempoSheetBody({required this.initial, required this.onSave});

  final MetronomeConfig initial;
  final Future<String?> Function(MetronomeConfig config) onSave;

  @override
  State<_TempoSheetBody> createState() => _TempoSheetBodyState();
}

class _TempoSheetBodyState extends State<_TempoSheetBody> {
  late final TextEditingController _bpm =
      TextEditingController(text: '${widget.initial.bpm}');
  late final TextEditingController _beats =
      TextEditingController(text: '${widget.initial.beatsPerMeasure}');
  late bool _accent = widget.initial.downbeatAccent;
  bool _saving = false;
  String? _error;

  int? get _bpmValue {
    final value = int.tryParse(_bpm.text);
    if (value == null) return null;
    return value >= TempoSheet.minBpm && value <= TempoSheet.maxBpm
        ? value
        : null;
  }

  int? get _beatsValue {
    final value = int.tryParse(_beats.text);
    if (value == null) return null;
    return value >= TempoSheet.minBeats && value <= TempoSheet.maxBeats
        ? value
        : null;
  }

  @override
  void dispose() {
    _bpm.dispose();
    _beats.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final bpm = _bpmValue;
    final beats = _beatsValue;
    if (bpm == null || beats == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onSave(MetronomeConfig(
      bpm: bpm,
      beatsPerMeasure: beats,
      downbeatAccent: _accent,
    ));
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final valid = _bpmValue != null && _beatsValue != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(CantaeRadii.radiusSheet),
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(CantaeSpacing.space5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Andamento',
                  style: CantaeTypography.titleSheet.copyWith(
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: CantaeSpacing.space4),
                _NumberField(
                  controller: _bpm,
                  label: 'BPM',
                  error: _bpmValue == null ? 'Entre 30 e 300' : null,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: CantaeSpacing.space3),
                _NumberField(
                  controller: _beats,
                  label: 'Tempos por compasso',
                  error: _beatsValue == null ? 'Entre 2 e 16' : null,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: CantaeSpacing.space3),
                SegmentedControl<bool>(
                  options: const [
                    SegmentedOption(label: 'Com acento', value: true),
                    SegmentedOption(label: 'Sem acento', value: false),
                  ],
                  selected: _accent,
                  onChanged: (value) => setState(() => _accent = value),
                ),
                if (_error != null) ...[
                  const SizedBox(height: CantaeSpacing.space3),
                  Semantics(
                    liveRegion: true,
                    child: InlineBanner(
                      variant: InlineBannerVariant.error,
                      title: 'Andamento não salvo',
                      message: _error!,
                    ),
                  ),
                ],
                const SizedBox(height: CantaeSpacing.space4),
                PrimaryButton(
                  label: 'Salvar andamento',
                  loading: _saving,
                  onPressed: valid ? _save : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.error,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? error;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final radius = BorderRadius.circular(CantaeRadii.radiusSm);

    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: CantaeTypography.mono.copyWith(color: colors.text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: CantaeTypography.body.copyWith(color: colors.text2),
        errorText: error,
        errorStyle: CantaeTypography.caption.copyWith(
          color: colors.dangerSolid,
        ),
        filled: true,
        fillColor: colors.fillField,
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: colors.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: colors.dangerSolid, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: colors.dangerSolid, width: 2),
        ),
      ),
    );
  }
}
