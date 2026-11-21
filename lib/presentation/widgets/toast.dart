import 'package:flutter/material.dart';

import '../theme/cantae_colors.dart';
import '../theme/cantae_spacing.dart';
import '../theme/cantae_typography.dart';

/// Transient feedback banner — `toastBg` background, `onToast` text, radius
/// 14, check icon, disappears on its own after ~2.5 s. See
/// `docs/design/COMPONENTS.md`'s `Toast`.
abstract final class Toast {
  static const Duration _visibleFor = Duration(milliseconds: 2500);

  static void show(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    final colors = Theme.of(context).extension<CantaeColors>()!;
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _ToastBanner(message: message, colors: colors),
    );

    overlay.insert(entry);
    Future<void>.delayed(_visibleFor, entry.remove);
  }
}

class _ToastBanner extends StatelessWidget {
  const _ToastBanner({required this.message, required this.colors});

  final String message;
  final CantaeColors colors;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: CantaeSpacing.space4,
      right: CantaeSpacing.space4,
      bottom: CantaeSpacing.space6,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: colors.toastBg,
            borderRadius: BorderRadius.circular(CantaeRadii.radiusMd),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: CantaeSpacing.space4,
            vertical: CantaeSpacing.space3,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check, color: colors.onToast, size: 18),
              const SizedBox(width: CantaeSpacing.space2),
              Flexible(
                child: Text(
                  message,
                  style: CantaeTypography.body.copyWith(color: colors.onToast),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
