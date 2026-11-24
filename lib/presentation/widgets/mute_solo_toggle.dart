import 'package:flutter/material.dart';

import '../theme/cantae_colors.dart';
import '../theme/cantae_spacing.dart';
import '../theme/cantae_typography.dart';

/// Square 44 dp toggle for a track's mute ("M") or solo ("S"). Shared by
/// `TrackAlignRow` and `MixTrackRow` (COMPONENTS.md). The on state is
/// announced as toggled, never shown by color alone (RNF-UX-05).
class MuteSoloToggle extends StatelessWidget {
  const MuteSoloToggle({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.active,
    required this.onTap,
  });

  /// Short visible label, e.g. "M".
  final String label;

  /// Full name read by screen readers, e.g. "Mudo".
  final String semanticLabel;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;

    return Semantics(
      button: true,
      toggled: active,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CantaeRadii.radiusXs),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? colors.accentSoft : colors.fillField,
            borderRadius: BorderRadius.circular(CantaeRadii.radiusXs),
          ),
          child: Text(
            label,
            style: CantaeTypography.label.copyWith(
              color: active ? colors.onAccentSoft : colors.text2,
            ),
          ),
        ),
      ),
    );
  }
}
