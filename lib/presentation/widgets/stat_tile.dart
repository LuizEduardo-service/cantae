import 'package:flutter/material.dart';

import '../theme/cantae_colors.dart';
import '../theme/cantae_spacing.dart';
import '../theme/cantae_typography.dart';

/// A large mono number with a caption (COMPONENTS.md `StatTile`), used in the
/// History summary. Screen readers hear "caption: value" as one item.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.caption});

  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;

    return Semantics(
      label: '$caption: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(CantaeSpacing.space3),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(CantaeRadii.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: CantaeTypography.monoStat.copyWith(color: colors.text),
              ),
            ),
            const SizedBox(height: CantaeSpacing.space1),
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CantaeTypography.caption.copyWith(color: colors.text2),
            ),
          ],
        ),
      ),
    );
  }
}
