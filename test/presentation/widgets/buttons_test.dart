import 'dart:ui' show Tristate;

import 'package:cantae/presentation/widgets/buttons.dart';
import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {required ThemeData theme}) {
  return MaterialApp(theme: theme, home: Scaffold(body: child));
}

void main() {
  group('PrimaryButton', () {
    testWidgets('normal state renders the label and fires onPressed', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          PrimaryButton(label: 'Criar sala', onPressed: () => tapped = true),
          theme: AppTheme.light,
        ),
      );

      expect(find.text('Criar sala'), findsOneWidget);
      await tester.tap(find.text('Criar sala'));
      expect(tapped, isTrue);
    });

    testWidgets('loading state shows an indicator and the label, blocks taps', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          PrimaryButton(
            label: 'Salvando',
            onPressed: () => tapped = true,
            loading: true,
          ),
          theme: AppTheme.light,
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Salvando'), findsOneWidget);

      await tester.tap(find.text('Salvando'), warnIfMissed: false);
      expect(tapped, isFalse);
    });

    testWidgets('disabled state (no onPressed) blocks taps', (tester) async {
      await tester.pumpWidget(
        _wrap(const PrimaryButton(label: 'Indisponível'), theme: AppTheme.light),
      );

      final semantics = tester.getSemantics(find.byType(PrimaryButton));
      expect(semantics.flagsCollection.isEnabled, Tristate.isFalse);
    });

    testWidgets('renders at pill height 54', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PrimaryButton(label: 'Criar sala', onPressed: () {}),
          theme: AppTheme.light,
        ),
      );

      final size = tester.getSize(find.byType(PrimaryButton));
      expect(size.height, 54);
    });

    testWidgets('renders under the dark theme without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PrimaryButton(label: 'Criar sala', onPressed: () {}),
          theme: AppTheme.dark,
        ),
      );

      expect(find.text('Criar sala'), findsOneWidget);
    });
  });

  group('SecondaryButton', () {
    testWidgets('normal state renders the label and fires onPressed', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          SecondaryButton(
            label: 'Entrar em sala',
            onPressed: () => tapped = true,
          ),
          theme: AppTheme.light,
        ),
      );

      expect(find.text('Entrar em sala'), findsOneWidget);
      await tester.tap(find.text('Entrar em sala'));
      expect(tapped, isTrue);
    });

    testWidgets('renders at pill height 54', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SecondaryButton(label: 'Entrar em sala', onPressed: () {}),
          theme: AppTheme.light,
        ),
      );

      final size = tester.getSize(find.byType(SecondaryButton));
      expect(size.height, 54);
    });

    testWidgets('renders under the dark theme without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SecondaryButton(label: 'Entrar em sala', onPressed: () {}),
          theme: AppTheme.dark,
        ),
      );

      expect(find.text('Entrar em sala'), findsOneWidget);
    });
  });
}
