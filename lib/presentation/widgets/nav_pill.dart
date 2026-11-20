import 'package:flutter/material.dart';

import '../theme/cantae_colors.dart';
import '../theme/cantae_spacing.dart';
import '../theme/cantae_typography.dart';

/// `NavPill` variants per `docs/design/COMPONENTS.md`.
enum NavPillVariant { back, exit, cancel, action }

/// Top navigation pill. `back` prefixes its [label] with "‹ "; the other
/// three variants render [label] as-is (caller decides the exact copy, e.g.
/// "Sair", "Cancelar", "Importar").
class NavPill extends StatelessWidget {
  const NavPill({
    super.key,
    required this.variant,
    required this.label,
    required this.onTap,
  });

  static const double _height = 44;

  final NavPillVariant variant;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final displayText = variant == NavPillVariant.back ? '‹ $label' : label;
    final radius = CantaeRadii.radiusPill(_height);

    return Semantics(
      button: true,
      label: displayText,
      child: Material(
        color: colors.fillMuted,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: _height,
              minWidth: _height,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CantaeSpacing.space4,
              ),
              child: Center(
                child: Text(
                  displayText,
                  style: CantaeTypography.label.copyWith(color: colors.text),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
