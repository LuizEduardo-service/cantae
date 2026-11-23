import 'package:flutter/material.dart';

import '../theme/cantae_colors.dart';
import '../theme/cantae_spacing.dart';
import '../theme/cantae_typography.dart';

/// One option of a [SegmentedControl]: a visible [label] and the [value] it
/// selects.
@immutable
class SegmentedOption<T> {
  const SegmentedOption({required this.label, required this.value});

  final String label;
  final T value;
}

/// Generic 2+ option segmented control. Track `fillField`, active segment
/// `segmentSelected` + shadow; inactive transparent `text2`. Exposes
/// radio-like ("mutually exclusive group") tab semantics per
/// `docs/design/COMPONENTS.md`'s `SegmentedControl`.
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  static const double _height = 42;
  static const double _trackPadding = 3;

  final List<SegmentedOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;

    return Container(
      height: _height,
      padding: const EdgeInsets.all(_trackPadding),
      decoration: BoxDecoration(
        color: colors.fillField,
        borderRadius: BorderRadius.circular(CantaeRadii.radiusSm),
      ),
      child: Row(
        children: options.map((option) {
          final isSelected = option.value == selected;
          return Expanded(
            child: Semantics(
              button: true,
              selected: isSelected,
              inMutuallyExclusiveGroup: true,
              label: option.label,
              child: GestureDetector(
                onTap: () => onChanged(option.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.segmentSelected
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(
                      CantaeRadii.radiusSegment,
                    ),
                    boxShadow: isSelected
                        ? const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    option.label,
                    style: CantaeTypography.label.copyWith(
                      color: isSelected ? colors.text : colors.text2,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
