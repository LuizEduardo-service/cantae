import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/cantae_colors.dart';
import '../theme/cantae_spacing.dart';
import '../theme/cantae_typography.dart';
import 'buttons.dart';
import 'toast.dart';

/// The room code on Criar sala (COMPONENTS.md `RoomCodeDisplay`): label,
/// the code in `monoLarge`, "Copiar" and one instruction line.
class RoomCodeDisplay extends StatelessWidget {
  const RoomCodeDisplay({
    super.key,
    required this.code,
    this.instruction =
        'Mostre este código para quem vai cantar. Ele aparece só nesta tela.',
  });

  final String code;
  final String instruction;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) Toast.show(context, 'Código copiado');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    return Container(
      padding: const EdgeInsets.all(CantaeSpacing.space5),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(CantaeRadii.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: 'Código da sala ${code.split('').join(' ')}',
            excludeSemantics: true,
            child: Column(
              children: [
                Text(
                  'Código da sala',
                  style: CantaeTypography.caption.copyWith(color: colors.text2),
                ),
                const SizedBox(height: CantaeSpacing.space2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    code,
                    style:
                        CantaeTypography.monoLarge.copyWith(color: colors.text),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: CantaeSpacing.space3),
          TonalButton(label: 'Copiar', onPressed: () => _copy(context)),
          const SizedBox(height: CantaeSpacing.space3),
          Text(
            instruction,
            textAlign: TextAlign.center,
            style: CantaeTypography.bodySmall.copyWith(color: colors.text2),
          ),
        ],
      ),
    );
  }
}
