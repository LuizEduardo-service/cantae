import 'package:flutter/material.dart';

import '../theme/cantae_colors.dart';
import '../theme/cantae_typography.dart';

/// A person in the room (COMPONENTS.md `RoomPersonRow`): name and role,
/// "Você · Mestre" or "Marina · Cantor". The minimal `ParticipantRow`,
/// without naipe or latency, until the full master room (ROOM-12, ROOM-39).
class RoomPersonRow extends StatelessWidget {
  const RoomPersonRow({super.key, required this.name, required this.role});

  static const double _minHeight = 44;

  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    return Semantics(
      label: '$name, $role',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _minHeight),
        child: Row(
          children: [
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CantaeTypography.body.copyWith(color: colors.text),
              ),
            ),
            Text(
              ' · $role',
              style: CantaeTypography.body.copyWith(color: colors.text2),
            ),
          ],
        ),
      ),
    );
  }
}
