import 'package:flutter/material.dart';

import '../theme/cantae_colors.dart';
import '../theme/cantae_spacing.dart';
import '../theme/cantae_typography.dart';

/// Status at the right of the top bar (COMPONENTS.md `StatusPill`). Only the
/// neutral variant exists so far ("Funciona offline" in Modo solo); the
/// synced / weak / offline variants arrive with the room screens.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label});

  static const double _height = 44;

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final radius = CantaeRadii.radiusPill(_height);

    return Semantics(
      liveRegion: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: colors.fillMuted,
        borderRadius: BorderRadius.circular(radius),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _height),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CantaeSpacing.space4,
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                label,
                style: CantaeTypography.label.copyWith(color: colors.text2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
