import 'dart:ui' show Tristate;

import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/widgets/confirm_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(ThemeData theme, Widget Function(BuildContext) buttonBuilder) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(body: Builder(builder: buttonBuilder)),
  );
}

void main() {
  group('ConfirmSheet', () {
    testWidgets('steps: 1 — tapping the destructive action resolves true', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        _wrap(
          AppTheme.light,
          (context) => ElevatedButton(
            onPressed: () async {
              result = await ConfirmSheet.show(
                context,
                title: 'Apagar música',
                message: 'Essa ação não pode ser desfeita.',
                safeLabel: 'Cancelar',
                destructiveLabel: 'Apagar definitivamente',
              );
            },
            child: const Text('abrir'),
          ),
        ),
      );

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Apagar música'), findsOneWidget);
      await tester.tap(find.text('Apagar definitivamente'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('steps: 1 — tapping the safe action resolves false', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        _wrap(
          AppTheme.light,
          (context) => ElevatedButton(
            onPressed: () async {
              result = await ConfirmSheet.show(
                context,
                title: 'Apagar música',
                message: 'Essa ação não pode ser desfeita.',
                safeLabel: 'Cancelar',
                destructiveLabel: 'Apagar definitivamente',
              );
            },
            child: const Text('abrir'),
          ),
        ),
      );

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets(
      'steps: 2 — final action stays disabled until typed text matches, case-insensitive',
      (tester) async {
        bool? result;
        await tester.pumpWidget(
          _wrap(
            AppTheme.light,
            (context) => ElevatedButton(
              onPressed: () async {
                result = await ConfirmSheet.show(
                  context,
                  title: 'Apagar todos os dados',
                  message: 'Digite APAGAR para confirmar.',
                  safeLabel: 'Cancelar',
                  destructiveLabel: 'Continuar',
                  steps: 2,
                  typedConfirmation: 'APAGAR',
                );
              },
              child: const Text('abrir'),
            ),
          ),
        );

        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();

        // Step 1: no text field yet, destructive action advances the step.
        expect(find.byType(TextField), findsNothing);
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();

        // Step 2: final action starts disabled.
        expect(find.byType(TextField), findsOneWidget);
        final disabledSemantics = tester.getSemantics(find.text('Continuar'));
        expect(disabledSemantics.flagsCollection.isEnabled, Tristate.isFalse);

        await tester.enterText(find.byType(TextField), 'apagar');
        await tester.pumpAndSettle();

        final enabledSemantics = tester.getSemantics(find.text('Continuar'));
        expect(enabledSemantics.flagsCollection.isEnabled, Tristate.isTrue);

        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();

        expect(result, isTrue);
      },
    );

    testWidgets('renders under the dark theme without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AppTheme.dark,
          (context) => ElevatedButton(
            onPressed: () => ConfirmSheet.show(
              context,
              title: 'Apagar música',
              message: 'Essa ação não pode ser desfeita.',
              safeLabel: 'Cancelar',
              destructiveLabel: 'Apagar definitivamente',
            ),
            child: const Text('abrir'),
          ),
        ),
      );

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Apagar música'), findsOneWidget);
    });
  });
}
