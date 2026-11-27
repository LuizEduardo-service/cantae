import 'package:flutter/material.dart';

import '../theme/cantae_colors.dart';
import '../theme/cantae_spacing.dart';
import '../theme/cantae_typography.dart';
import 'buttons.dart';

/// A pending request on the master's screen (COMPONENTS.md
/// `JoinRequestRow`): the name, "Recusar" and "Aprovar". With the room
/// full, "Aprovar" is off and the row says why (ROOM-11, ROOM-14, ROOM-54).
class JoinRequestRow extends StatelessWidget {
  const JoinRequestRow({
    super.key,
    required this.name,
    required this.onReject,
    required this.onApprove,
    this.roomFull = false,
  });

  final String name;
  final VoidCallback onReject;
  final VoidCallback onApprove;
  final bool roomFull;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CantaeSpacing.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CantaeTypography.listTitle.copyWith(color: colors.text),
            ),
          ),
          const SizedBox(height: CantaeSpacing.space2),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  container: true,
                  child: TonalButton(
                    label: 'Recusar',
                    semanticLabel: 'Recusar $name',
                    onPressed: onReject,
                  ),
                ),
              ),
              const SizedBox(width: CantaeSpacing.space2),
              Expanded(
                child: Semantics(
                  container: true,
                  child: TonalButton(
                    label: 'Aprovar',
                    semanticLabel: 'Aprovar $name',
                    positive: true,
                    onPressed: roomFull ? null : onApprove,
                  ),
                ),
              ),
            ],
          ),
          if (roomFull) ...[
            const SizedBox(height: CantaeSpacing.space1),
            Semantics(
              container: true,
              liveRegion: true,
              child: Text(
                'Sala cheia: 8 de 8.',
                style: CantaeTypography.bodySmall.copyWith(color: colors.text2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
