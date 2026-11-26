import 'package:flutter/material.dart';

import '../../domain/entities/custom_naipe.dart';
import '../../domain/entities/naipe.dart';
import '../theme/cantae_colors.dart';
import '../theme/cantae_spacing.dart';
import '../theme/cantae_typography.dart';
import 'mute_solo_toggle.dart';
import 'naipe_labels.dart';

/// One track in Modo solo's "Mix por naipe" (COMPONENTS.md `MixTrackRow`):
/// selo + name, M (mudo) and S (solo), and a volume slider below.
///
/// [naipe] is null for the Playback track, which has no naipe selo.
class MixTrackRow extends StatelessWidget {
  const MixTrackRow({
    super.key,
    required this.naipe,
    required this.label,
    required this.volume,
    required this.muted,
    required this.solo,
    required this.onVolumeChanged,
    required this.onMuteToggled,
    required this.onSoloToggled,
    this.showSolo = true,
    this.customNaipe,
  });

  final Naipe? naipe;

  /// The named custom naipe, shown with the neutral badge.
  final CustomNaipe? customNaipe;
  final String label;

  /// 0.0..1.0.
  final double volume;
  final bool muted;
  final bool solo;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onMuteToggled;
  final VoidCallback onSoloToggled;

  /// False hides S, e.g. for the metronome row, where soloing the click
  /// makes no sense.
  final bool showSolo;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final naipe = this.naipe;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (naipe != null) ...[
              NaipeBadge(naipe: naipe, customNaipe: customNaipe),
              const SizedBox(width: CantaeSpacing.space2),
            ],
            Expanded(
              child: Text(
                label,
                style: CantaeTypography.listTitle.copyWith(color: colors.text),
              ),
            ),
            MuteSoloToggle(
              label: 'M',
              semanticLabel: 'Mudo',
              active: muted,
              onTap: onMuteToggled,
            ),
            if (showSolo) ...[
              const SizedBox(width: CantaeSpacing.space1),
              MuteSoloToggle(
                label: 'S',
                semanticLabel: 'Solo',
                active: solo,
                onTap: onSoloToggled,
              ),
            ],
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: Slider(
            label: 'Volume do $label',
            value: volume.clamp(0.0, 1.0),
            activeColor: colors.accent,
            inactiveColor: colors.fillSecondary,
            semanticFormatterCallback: (value) => '${(value * 100).round()} %',
            onChanged: onVolumeChanged,
          ),
        ),
      ],
    );
  }
}
