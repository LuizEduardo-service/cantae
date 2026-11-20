import 'package:flutter/material.dart';

import '../theme/cantae_colors.dart';
import '../theme/cantae_spacing.dart';
import '../theme/cantae_typography.dart';

/// Library search input. `fillField` background, search icon, placeholder
/// "Buscar música ou autor". See `docs/design/COMPONENTS.md`'s `SearchField`.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.onChanged,
    this.enabled = true,
    this.controller,
  });

  static const double _height = 44;

  final ValueChanged<String> onChanged;

  /// When `false`, the field blocks interaction — used while the library's
  /// first load is still pending (nothing to filter yet).
  final bool enabled;

  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;

    return Container(
      height: _height,
      decoration: BoxDecoration(
        color: colors.fillField,
        borderRadius: BorderRadius.circular(CantaeRadii.radiusSm),
      ),
      padding: const EdgeInsets.symmetric(horizontal: CantaeSpacing.space3),
      child: Row(
        children: [
          Icon(Icons.search, color: colors.text2, size: 20),
          const SizedBox(width: CantaeSpacing.space2),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              onChanged: onChanged,
              style: CantaeTypography.body.copyWith(color: colors.text),
              decoration: InputDecoration(
                hintText: 'Buscar música ou autor',
                hintStyle: CantaeTypography.body.copyWith(color: colors.text2),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
