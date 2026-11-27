import 'package:flutter/material.dart';

import '../theme/cantae_colors.dart';
import '../theme/cantae_spacing.dart';
import '../theme/cantae_typography.dart';

/// `neutral` ("Funciona offline", "Sala 4827") or `synced` ("Visível neste
/// Wi‑Fi"). The weak / offline variants arrive with the full room screens.
enum StatusPillVariant { neutral, synced }

/// Status at the right of the top bar (COMPONENTS.md `StatusPill`), read
/// as a live region.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.variant = StatusPillVariant.neutral,
  });

  static const double _height = 44;
  static const double _dot = 8;

  final String label;
  final StatusPillVariant variant;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final radius = CantaeRadii.radiusPill(_height);
    final synced = variant == StatusPillVariant.synced;

    return Semantics(
      liveRegion: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: synced ? colors.accentSoft : colors.fillMuted,
        borderRadius: BorderRadius.circular(radius),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _height),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CantaeSpacing.space4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (synced) ...[
                  Container(
                    key: const ValueKey('status-pill-dot'),
                    width: _dot,
                    height: _dot,
                    decoration: BoxDecoration(
                      color: colors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: CantaeSpacing.space2),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: CantaeTypography.label.copyWith(
                      color: synced ? colors.onAccentSoft : colors.text2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
