import 'dart:ui' show Tristate;

import 'package:cantae/presentation/widgets/buttons.dart';
import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/theme/cantae_colors.dart';
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
        _wrap(const PrimaryButton(label: 'Indisponível'),
            theme: AppTheme.light),
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

  group('TonalButton', () {
    Color fillOf(WidgetTester tester) => tester
        .widget<Material>(find.descendant(
          of: find.byType(TonalButton),
          matching: find.byType(Material),
        ))
        .color!;

    testWidgets('neutral uses fillOnSurface and fires onPressed', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        TonalButton(
          label: 'Marcar início do loop',
          onPressed: () => tapped = true,
        ),
        theme: AppTheme.light,
      ));
      final colors = AppTheme.light.extension<CantaeColors>()!;

      expect(fillOf(tester), colors.fillOnSurface);
      await tester.tap(find.text('Marcar início do loop'));
      expect(tapped, isTrue);
    });

    testWidgets('positive uses accentSoft with onAccentSoft text', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(
        TonalButton(label: 'Desligar loop', positive: true, onPressed: () {}),
        theme: AppTheme.light,
      ));
      final colors = AppTheme.light.extension<CantaeColors>()!;

      expect(fillOf(tester), colors.accentSoft);
      final text = tester.widget<Text>(find.text('Desligar loop'));
      expect(text.style!.color, colors.onAccentSoft);
    });

    testWidgets('disabled (no onPressed): blocks taps, announced as disabled',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(
        const TonalButton(label: 'Marcar início do loop'),
        theme: AppTheme.light,
      ));
      final colors = AppTheme.light.extension<CantaeColors>()!;

      final node = tester.getSemantics(find.byType(TonalButton));
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isEnabled, Tristate.isFalse);
      final text = tester.widget<Text>(find.text('Marcar início do loop'));
      expect(text.style!.color, colors.textDisabled);
      handle.dispose();
    });

    testWidgets('is 44 dp tall', (tester) async {
      await tester.pumpWidget(_wrap(
        TonalButton(label: 'Desligar loop', onPressed: () {}),
        theme: AppTheme.light,
      ));

      expect(tester.getSize(find.byType(TonalButton)).height, 44);
    });

    testWidgets('renders under the dark theme with its tokens', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(
        TonalButton(label: 'Desligar loop', positive: true, onPressed: () {}),
        theme: AppTheme.dark,
      ));
      final colors = AppTheme.dark.extension<CantaeColors>()!;

      expect(tester.takeException(), isNull);
      expect(fillOf(tester), colors.accentSoft);
    });
  });

  group('DestructiveButton', () {
    testWidgets('tonal variant renders dangerBg background and onDanger text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          DestructiveButton(
            label: 'Apagar desta música',
            onPressed: () {},
          ),
          theme: AppTheme.light,
        ),
      );

      expect(find.text('Apagar desta música'), findsOneWidget);
      final material = tester.widget<Material>(
        find
            .ancestor(of: find.byType(InkWell), matching: find.byType(Material))
            .first,
      );
      expect(
          material.color, AppTheme.light.extension<CantaeColors>()!.dangerBg);
      final text = tester.widget<Text>(find.text('Apagar desta música'));
      expect(
        text.style?.color,
        AppTheme.light.extension<CantaeColors>()!.onDanger,
      );
    });

    testWidgets('solid variant renders dangerSolid background and white text', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          DestructiveButton(
            label: 'Apagar definitivamente',
            variant: DestructiveButtonVariant.solid,
            onPressed: () => tapped = true,
          ),
          theme: AppTheme.light,
        ),
      );

      final material = tester.widget<Material>(
        find
            .ancestor(of: find.byType(InkWell), matching: find.byType(Material))
            .first,
      );
      expect(
        material.color,
        AppTheme.light.extension<CantaeColors>()!.dangerSolid,
      );
      final text = tester.widget<Text>(find.text('Apagar definitivamente'));
      expect(text.style?.color, Colors.white);

      await tester.tap(find.text('Apagar definitivamente'));
      expect(tapped, isTrue);
    });

    testWidgets('disabled state (no onPressed) blocks taps', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DestructiveButton(label: 'Indisponível'),
          theme: AppTheme.light,
        ),
      );

      final semantics = tester.getSemantics(find.byType(DestructiveButton));
      expect(semantics.flagsCollection.isEnabled, Tristate.isFalse);
    });

    testWidgets('renders under the dark theme without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          DestructiveButton(
            label: 'Apagar desta música',
            onPressed: () {},
          ),
          theme: AppTheme.dark,
        ),
      );

      expect(find.text('Apagar desta música'), findsOneWidget);
    });
  });
}
