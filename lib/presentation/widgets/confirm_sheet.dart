import 'package:flutter/material.dart';

import '../theme/cantae_colors.dart';
import '../theme/cantae_spacing.dart';
import '../theme/cantae_typography.dart';
import 'buttons.dart';

/// Bottom sheet for irreversible/destructive confirmations, per
/// `docs/design/COMPONENTS.md`'s `ConfirmSheet`. `steps: 2` requires
/// [ConfirmSheet.show]'s `typedConfirmation` and gates the final action
/// behind a case-insensitive match (`UI_GUIDELINES.md` §11).
class ConfirmSheet {
  const ConfirmSheet._();

  /// Opens the sheet. Resolves to `true` only if the user reaches and
  /// confirms the final (destructive) step; `false` on any cancel/dismiss.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    required String safeLabel,
    required String destructiveLabel,
    int steps = 1,
    String? typedConfirmation,
  }) async {
    assert(steps == 1 || steps == 2, 'ConfirmSheet supports 1 or 2 steps');
    assert(
      steps != 2 || typedConfirmation != null,
      'steps: 2 requires typedConfirmation',
    );

    final colors = Theme.of(context).extension<CantaeColors>()!;
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: colors.scrim,
      builder: (context) => _ConfirmSheetBody(
        title: title,
        message: message,
        safeLabel: safeLabel,
        destructiveLabel: destructiveLabel,
        steps: steps,
        typedConfirmation: typedConfirmation,
      ),
    );
    return result ?? false;
  }
}

class _ConfirmSheetBody extends StatefulWidget {
  const _ConfirmSheetBody({
    required this.title,
    required this.message,
    required this.safeLabel,
    required this.destructiveLabel,
    required this.steps,
    required this.typedConfirmation,
  });

  final String title;
  final String message;
  final String safeLabel;
  final String destructiveLabel;
  final int steps;
  final String? typedConfirmation;

  @override
  State<_ConfirmSheetBody> createState() => _ConfirmSheetBodyState();
}

class _ConfirmSheetBodyState extends State<_ConfirmSheetBody> {
  int _step = 1;
  String _typedText = '';

  bool get _onFinalStep => _step == widget.steps;

  bool get _finalActionEnabled {
    if (!_onFinalStep) return true;
    final expected = widget.typedConfirmation;
    if (expected == null) return true;
    return _typedText.toLowerCase() == expected.toLowerCase();
  }

  void _onDestructiveTap() {
    if (_onFinalStep) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _step++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(CantaeRadii.radiusSheet),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(CantaeSpacing.space5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: CantaeTypography.titleSheet.copyWith(
                  color: colors.text,
                ),
              ),
              const SizedBox(height: CantaeSpacing.space2),
              Text(
                widget.message,
                style: CantaeTypography.body.copyWith(color: colors.textBody),
              ),
              if (_onFinalStep && widget.typedConfirmation != null) ...[
                const SizedBox(height: CantaeSpacing.space4),
                TextField(
                  autofocus: true,
                  onChanged: (value) => setState(() => _typedText = value),
                  style: CantaeTypography.body.copyWith(color: colors.text),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colors.fillField,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        CantaeRadii.radiusMd,
                      ),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: CantaeSpacing.space5),
              DestructiveButton(
                label: widget.destructiveLabel,
                variant: DestructiveButtonVariant.solid,
                onPressed: _finalActionEnabled ? _onDestructiveTap : null,
              ),
              const SizedBox(height: CantaeSpacing.space2),
              SecondaryButton(
                label: widget.safeLabel,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
