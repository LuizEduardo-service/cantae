import 'package:flutter/material.dart';

import '../theme/cantae_colors.dart';
import '../theme/cantae_spacing.dart';
import '../theme/cantae_typography.dart';

/// Fixed-height pill buttons sharing one file — cohesive, differing only in
/// color/role. See `docs/design/COMPONENTS.md`'s `PrimaryButton`.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
  });

  static const double _height = 54;

  final String label;
  final VoidCallback? onPressed;

  /// Shows an indicator alongside the label and blocks further taps.
  final bool loading;

  bool get _disabled => onPressed == null || loading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final radius = CantaeRadii.radiusPill(_height);
    final isPlainDisabled = onPressed == null && !loading;
    final background = isPlainDisabled ? colors.fillField : colors.accent;
    final foreground = isPlainDisabled ? colors.text2 : colors.onAccent;

    return Semantics(
      button: true,
      enabled: !_disabled,
      label: label,
      child: SizedBox(
        width: double.infinity,
        height: _height,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(radius),
          child: InkWell(
            onTap: _disabled ? null : onPressed,
            borderRadius: BorderRadius.circular(radius),
            child: Center(
              child: loading
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: foreground,
                          ),
                        ),
                        const SizedBox(width: CantaeSpacing.space2),
                        Text(
                          label,
                          style: CantaeTypography.label.copyWith(
                            color: foreground,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      label,
                      style: CantaeTypography.label.copyWith(
                        color: foreground,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// See `docs/design/COMPONENTS.md`'s `SecondaryButton`.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, this.onPressed});

  static const double _height = 54;

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final radius = CantaeRadii.radiusPill(_height);

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: SizedBox(
        width: double.infinity,
        height: _height,
        child: Material(
          color: colors.fillSecondary,
          borderRadius: BorderRadius.circular(radius),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(radius),
            child: Center(
              child: Text(
                label,
                style: CantaeTypography.label.copyWith(color: colors.text),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `tonal` starts a destructive flow (e.g. "Apagar desta música"); `solid`
/// confirms it (e.g. "Apagar definitivamente"). See `COMPONENTS.md`'s
/// `DestructiveButton`.
enum DestructiveButtonVariant { tonal, solid }

/// See `docs/design/COMPONENTS.md`'s `DestructiveButton`.
class DestructiveButton extends StatelessWidget {
  const DestructiveButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = DestructiveButtonVariant.tonal,
  });

  static const double _height = 54;

  final String label;
  final VoidCallback? onPressed;
  final DestructiveButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final radius = CantaeRadii.radiusPill(_height);
    final isDisabled = onPressed == null;
    final background = isDisabled
        ? colors.fillField
        : (variant == DestructiveButtonVariant.tonal
            ? colors.dangerBg
            : colors.dangerSolid);
    final foreground = isDisabled
        ? colors.text2
        : (variant == DestructiveButtonVariant.tonal
            ? colors.onDanger
            : Colors.white);

    return Semantics(
      button: true,
      enabled: !isDisabled,
      label: label,
      child: SizedBox(
        width: double.infinity,
        height: _height,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(radius),
          child: InkWell(
            onTap: onPressed,
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
