import 'dart:ui' show Tristate;

import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/widgets/segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {required ThemeData theme}) {
  return MaterialApp(theme: theme, home: Scaffold(body: child));
}

const _options = [
  SegmentedOption(label: 'Todas', value: 'all'),
  SegmentedOption(label: 'Criadas', value: 'created'),
  SegmentedOption(label: 'Recebidas', value: 'received'),
];

void main() {
  group('SegmentedControl', () {
    testWidgets('renders every option label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SegmentedControl<String>(
            options: _options,
            selected: 'all',
            onChanged: (_) {},
          ),
          theme: AppTheme.light,
        ),
      );

      expect(find.text('Todas'), findsOneWidget);
      expect(find.text('Criadas'), findsOneWidget);
      expect(find.text('Recebidas'), findsOneWidget);
    });

    testWidgets('tapping a segment fires onChanged with its value', (
      tester,
    ) async {
      String? received;
      await tester.pumpWidget(
        _wrap(
          SegmentedControl<String>(
            options: _options,
            selected: 'all',
            onChanged: (value) => received = value,
          ),
          theme: AppTheme.light,
        ),
      );

      await tester.tap(find.text('Criadas'));
      expect(received, 'created');
    });

    testWidgets('marks the selected segment as selected in semantics', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SegmentedControl<String>(
            options: _options,
            selected: 'created',
            onChanged: (_) {},
          ),
          theme: AppTheme.light,
        ),
      );

      final selectedSemantics = tester.getSemantics(find.text('Criadas'));
      final unselectedSemantics = tester.getSemantics(find.text('Todas'));

      expect(selectedSemantics.flagsCollection.isSelected, Tristate.isTrue);
      expect(unselectedSemantics.flagsCollection.isSelected, Tristate.isFalse);
    });

    testWidgets(
      'visual selection state follows the selected prop (segmentSelected background)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            SegmentedControl<String>(
              options: _options,
              selected: 'created',
              onChanged: (_) {},
            ),
            theme: AppTheme.light,
          ),
        );

        final container = tester.widget<AnimatedContainer>(
          find.ancestor(
            of: find.text('Criadas'),
            matching: find.byType(AnimatedContainer),
          ),
        );
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, const Color(0xFFFFFFFF));
      },
    );

    testWidgets('renders under the dark theme without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SegmentedControl<String>(
            options: _options,
            selected: 'all',
            onChanged: (_) {},
          ),
          theme: AppTheme.dark,
        ),
      );

      expect(find.text('Todas'), findsOneWidget);
    });
  });
}
