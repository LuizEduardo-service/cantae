import 'package:flutter/material.dart';

import '../theme/cantae_colors.dart';
import '../theme/cantae_spacing.dart';
import '../theme/cantae_typography.dart';

/// Generic empty-state block: icon, title, message, a primary action and an
/// optional secondary action. See `docs/design/COMPONENTS.md`'s `EmptyState`.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  static const double _iconSize = 72;
  static const double _actionHeight = 54;

  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: CantaeSpacing.space5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _iconSize,
              height: _iconSize,
              decoration: BoxDecoration(
                color: colors.accentSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: colors.onAccentSoft, size: 36),
            ),
            const SizedBox(height: CantaeSpacing.space4),
            Text(
              title,
              textAlign: TextAlign.center,
              // SPEC_DEVIATION: COMPONENTS.md specifies 28/700 for this
              // title; no token in the typography scale is exactly 28/700.
              // titleSheet (26/700) is the closest documented token.
              style: CantaeTypography.titleSheet.copyWith(color: colors.text),
            ),
            const SizedBox(height: CantaeSpacing.space2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: CantaeTypography.body.copyWith(color: colors.textBody),
            ),
            const SizedBox(height: CantaeSpacing.space6),
            _Action(
              label: primaryLabel,
              onTap: onPrimary,
              background: colors.accent,
              foreground: colors.onAccent,
            ),
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: CantaeSpacing.space2),
              _Action(
                label: secondaryLabel!,
                onTap: onSecondary!,
                background: colors.fillSecondary,
                foreground: colors.text,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.onTap,
    required this.background,
    required this.foreground,
  });

  final String label;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final radius = CantaeRadii.radiusPill(EmptyState._actionHeight);
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: double.infinity,
        height: EmptyState._actionHeight,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(radius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(radius),
            child: Center(
              child: Text(
                label,
                style: CantaeTypography.label.copyWith(color: foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
