import 'package:cantae/domain/entities/metronome_config.dart';
import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/widgets/buttons.dart';
import 'package:cantae/presentation/widgets/tempo_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _initial = MetronomeConfig(bpm: 72, beatsPerMeasure: 4);

/// A button that opens the sheet, and the configs `onSave` received.
Future<List<MetronomeConfig>> _open(
  WidgetTester tester, {
  MetronomeConfig initial = _initial,
  String? Function(MetronomeConfig)? answer,
  ThemeData? theme,
}) async {
  final saved = <MetronomeConfig>[];
  await tester.pumpWidget(MaterialApp(
    theme: theme ?? AppTheme.light,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => TempoSheet.show(
            context,
            initial: initial,
            onSave: (config) async {
              saved.add(config);
              return answer?.call(config);
            },
          ),
          child: const Text('abrir'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return saved;
}

Finder _field(String label) => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == label,
    );

PrimaryButton _save(WidgetTester tester) => tester.widget<PrimaryButton>(
    find.widgetWithText(PrimaryButton, 'Salvar andamento'));

void main() {
  group('TempoSheet', () {
    testWidgets('shows the title and the initial values', (tester) async {
      await _open(tester,
          initial: const MetronomeConfig(
            bpm: 96,
            beatsPerMeasure: 3,
            downbeatAccent: false,
          ));

      expect(find.text('Andamento'), findsOneWidget);
      expect(tester.widget<TextField>(_field('BPM')).controller!.text, '96');
      expect(
        tester
            .widget<TextField>(_field('Tempos por compasso'))
            .controller!
            .text,
        '3',
      );
      expect(find.text('Sem acento'), findsOneWidget);
    });

    testWidgets('BPM out of 30–300 shows the limit and disables saving',
        (tester) async {
      await _open(tester);

      for (final value in ['29', '301', '']) {
        await tester.enterText(_field('BPM'), value);
        await tester.pump();
        expect(find.text('Entre 30 e 300'), findsOneWidget, reason: value);
        expect(_save(tester).onPressed, isNull, reason: value);
      }
    });

    testWidgets('beats out of 2–16 shows the limit and disables saving',
        (tester) async {
      await _open(tester);

      for (final value in ['1', '17']) {
        await tester.enterText(_field('Tempos por compasso'), value);
        await tester.pump();
        expect(find.text('Entre 2 e 16'), findsOneWidget, reason: value);
        expect(_save(tester).onPressed, isNull, reason: value);
      }
    });

    testWidgets('valid values are saved and the sheet closes', (tester) async {
      final saved = await _open(tester);

      await tester.enterText(_field('BPM'), '96');
      await tester.enterText(_field('Tempos por compasso'), '3');
      await tester.tap(find.text('Sem acento'));
      await tester.pump();
      await tester.tap(find.text('Salvar andamento'));
      await tester.pumpAndSettle();

      expect(saved, hasLength(1));
      expect(saved.single.bpm, 96);
      expect(saved.single.beatsPerMeasure, 3);
      expect(saved.single.downbeatAccent, isFalse);
      expect(find.text('Andamento'), findsNothing);
    });

    testWidgets('a save error keeps the sheet open with the typed values',
        (tester) async {
      await _open(tester,
          answer: (_) => 'Não foi possível salvar o andamento.');

      await tester.enterText(_field('BPM'), '120');
      await tester.tap(find.text('Salvar andamento'));
      await tester.pumpAndSettle();

      expect(find.text('Andamento'), findsOneWidget);
      expect(find.text('Não foi possível salvar o andamento.'), findsOneWidget);
      expect(tester.widget<TextField>(_field('BPM')).controller!.text, '120');
    });

    testWidgets('fields are labelled for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await _open(tester);

      expect(find.bySemanticsLabel(RegExp('BPM')), findsWidgets);
      expect(
          find.bySemanticsLabel(RegExp('Tempos por compasso')), findsWidgets);
      handle.dispose();
    });

    testWidgets('renders under the dark theme', (tester) async {
      await _open(tester, theme: AppTheme.dark);

      expect(tester.takeException(), isNull);
      expect(find.text('Salvar andamento'), findsOneWidget);
    });

    testWidgets('360 dp at 130% font: lays out without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await _open(tester);
      await tester.enterText(_field('BPM'), '5');
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Entre 30 e 300'), findsOneWidget);
    });
  });
}
