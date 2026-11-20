import 'package:flutter/material.dart';

import '../../theme/cantae_colors.dart';
import '../../theme/cantae_spacing.dart';
import '../../theme/cantae_typography.dart';
import '../../widgets/cantae_scaffold.dart';
import '../../widgets/nav_pill.dart';
import '../../widgets/empty_state.dart';

/// Shared placeholder for every named route that doesn't have its own
/// screen yet (`song-detail`, `room-create`, `room-join`, `profile`,
/// `package-import`). See `spec.md`'s Assumptions table.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;

    return CantaeScaffold(
      topLeft: NavPill(
        variant: NavPillVariant.back,
        label: 'Voltar',
        onTap: () => Navigator.of(context).maybePop(),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: CantaeSpacing.space4),
          Text(
            title,
            style: CantaeTypography.titlePage.copyWith(color: colors.text),
          ),
          Expanded(
            child: EmptyState(
              icon: Icons.hourglass_top,
              title: 'Em breve',
              message: 'Essa tela ainda está sendo construída.',
              primaryLabel: 'Voltar',
              onPrimary: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }
}
