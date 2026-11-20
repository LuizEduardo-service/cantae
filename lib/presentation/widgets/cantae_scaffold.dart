import 'package:flutter/material.dart';

import '../theme/cantae_colors.dart';
import '../theme/cantae_spacing.dart';

/// Base screen shell: top row (left/right slots), scrollable body, optional
/// fixed footer. See `docs/design/COMPONENTS.md`'s `CantaeScaffold`.
class CantaeScaffold extends StatelessWidget {
  const CantaeScaffold({
    super.key,
    this.topLeft,
    this.topRight,
    required this.body,
    this.footer,
  });

  /// Widget shown at the left of the top row (e.g. a back `NavPill`).
  final Widget? topLeft;

  /// Widget shown at the right of the top row (e.g. an action `NavPill`).
  final Widget? topRight;

  /// The screen's main (scrollable) content.
  final Widget body;

  /// Optional fixed footer, rendered below the body with its own padding.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;

    return Material(
      color: colors.bg,
      child: SafeArea(
        child: Column(
          children: [
            if (topLeft != null || topRight != null)
              Padding(
                padding: const EdgeInsets.only(
                  left: CantaeSpacing.space5,
                  right: CantaeSpacing.space5,
                  top: CantaeSpacing.space3,
                ),
                child: Row(
                  children: [
                    if (topLeft != null) Flexible(child: topLeft!),
                    const Spacer(),
                    if (topRight != null) Flexible(child: topRight!),
                  ],
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CantaeSpacing.space5,
                ),
                child: body,
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.only(
                  left: CantaeSpacing.space5,
                  right: CantaeSpacing.space5,
                  top: CantaeSpacing.space3,
                  bottom: CantaeSpacing.safeBottom,
                ),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}
