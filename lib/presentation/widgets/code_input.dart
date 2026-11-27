import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/cantae_colors.dart';
import '../theme/cantae_spacing.dart';
import '../theme/cantae_typography.dart';

/// The 4-digit room code field (COMPONENTS.md `CodeInput`): Geist Mono
/// 28/+8, numeric keyboard, digits only, error border when the code was
/// not found (ROOM-26, ROOM-27).
class CodeInput extends StatelessWidget {
  const CodeInput({
    super.key,
    required this.controller,
    this.focusNode,
    this.hasError = false,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
  });

  static const int length = 4;

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool hasError;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(CantaeRadii.radiusMd),
          borderSide: BorderSide(color: color, width: width),
        );
    final idle =
        hasError ? border(colors.dangerSolid, 2) : border(colors.divider, 1);
    return Semantics(
      label: 'Código da sala',
      textField: true,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        textAlign: TextAlign.center,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(length),
        ],
        style: CantaeTypography.monoInput.copyWith(
          color: enabled ? colors.text : colors.textDisabled,
        ),
        decoration: InputDecoration(
          hintText: '0000',
          hintStyle: CantaeTypography.monoInput.copyWith(color: colors.text3),
          filled: true,
          fillColor: colors.fillField,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(
            vertical: CantaeSpacing.space3,
            horizontal: CantaeSpacing.space4,
          ),
          enabledBorder: idle,
          disabledBorder: border(colors.divider, 1),
          focusedBorder: hasError ? idle : border(colors.accent, 2),
        ),
      ),
    );
  }
}
