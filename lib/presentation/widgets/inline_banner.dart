import 'package:flutter/material.dart';

import '../theme/cantae_colors.dart';
import '../theme/cantae_spacing.dart';
import '../theme/cantae_typography.dart';

/// `docs/design/COMPONENTS.md`'s `InlineBanner`: card with raio 16, padding
/// 14–16, title 17/700, body 15, optional tonal action in the banner's own
/// text color.
enum InlineBannerVariant { info, success, warning, error }

class InlineBanner extends StatelessWidget {
  const InlineBanner({
    super.key,
    required this.variant,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final InlineBannerVariant variant;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final (background, onColor) = switch (variant) {
      InlineBannerVariant.info => (colors.surface, colors.text),
      InlineBannerVariant.success => (colors.accentSoft, colors.onAccentSoft),
      InlineBannerVariant.warning => (colors.warningBg, colors.onWarning),
      InlineBannerVariant.error => (colors.dangerBg, colors.onDanger),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(CantaeSpacing.space4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(CantaeRadii.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              style: CantaeTypography.listTitle.copyWith(color: onColor)),
          const SizedBox(height: CantaeSpacing.space1),
          Text(message,
              style: CantaeTypography.bodySmall.copyWith(color: onColor)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: CantaeSpacing.space3),
            Semantics(
              button: true,
              label: actionLabel,
              child: InkWell(
                onTap: onAction,
                child: Text(
                  actionLabel!,
                  style: CantaeTypography.label.copyWith(color: onColor),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
