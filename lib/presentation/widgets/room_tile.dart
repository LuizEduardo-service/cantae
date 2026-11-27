import 'package:flutter/material.dart';

import '../theme/cantae_colors.dart';
import '../theme/cantae_spacing.dart';
import '../theme/cantae_typography.dart';

/// A room found on the Wi‑Fi (COMPONENTS.md `RoomTile`): the master's name
/// and the song, never the code (NET-01). A 2 px `accent` border marks the
/// chosen room or the one with a request in progress (ROOM-28, ROOM-29).
class RoomTile extends StatelessWidget {
  const RoomTile({
    super.key,
    required this.masterName,
    this.songName,
    this.selected = false,
    this.onTap,
  });

  static const double _minHeight = 64;

  final String masterName;
  final String? songName;
  final bool selected;

  /// Null disables the tile (another request is in progress).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final enabled = onTap != null;
    final song = songName ?? 'Sem música escolhida';
    final radius = BorderRadius.circular(CantaeRadii.radiusLg);
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: 'Sala de $masterName, $song',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: selected
              ? BorderSide(color: colors.accent, width: 2)
              : BorderSide(color: colors.divider),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _minHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CantaeSpacing.space4,
                vertical: CantaeSpacing.space3,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Sala de $masterName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CantaeTypography.listTitle.copyWith(
                            color: enabled ? colors.text : colors.textDisabled,
                          ),
                        ),
                        const SizedBox(height: CantaeSpacing.space1),
                        Text(
                          song,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CantaeTypography.bodySmall.copyWith(
                            color: enabled ? colors.text2 : colors.textDisabled,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: CantaeSpacing.space2),
                  Icon(
                    Icons.chevron_right,
                    color: enabled ? colors.text3 : colors.textDisabled,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
