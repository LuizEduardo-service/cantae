import 'package:cantae/domain/audio/lyric_cursor.dart';
import 'package:cantae/domain/entities/lyric_line.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/widgets/lyric_view.dart';
import 'package:cantae/presentation/widgets/voice_part_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _lines = [
  LyricLine(text: 'Ave verum corpus', onsetMs: 2000),
  LyricLine(
    text: 'natum de Maria Virgine',
    onsetMs: 5000,
    naipe: Naipe.tenor,
    dynamics: 'piano',
  ),
  LyricLine(text: 'vere passum immolatum', onsetMs: 9000),
];

Widget _view(
  List<LyricLine> lines,
  int positionMs, {
  ThemeData? theme,
}) =>
    MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Scaffold(
        body: LyricView(
          lines: lines,
          cursor: LyricCursor.at(lines, positionMs),
        ),
      ),
    );

void main() {
  group('LyricView', () {
    testWidgets('before the first line: only "Próxima" and the first line',
        (tester) async {
      await tester.pumpWidget(_view(_lines, 1000));

      expect(find.text('Próxima'), findsOneWidget);
      expect(find.text('Ave verum corpus'), findsOneWidget);
      expect(find.text('natum de Maria Virgine'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Linha atual')), findsNothing);
    });

    testWidgets('middle: past line, active card and the next line',
        (tester) async {
      await tester.pumpWidget(_view(_lines, 6000));

      expect(find.text('Ave verum corpus'), findsOneWidget);
      expect(find.text('natum de Maria Virgine'), findsOneWidget);
      expect(find.text('Próxima'), findsOneWidget);
      expect(find.text('vere passum immolatum'), findsOneWidget);
    });

    testWidgets('on the last line there is no "Próxima"', (tester) async {
      await tester.pumpWidget(_view(_lines, 60000));

      expect(find.text('vere passum immolatum'), findsOneWidget);
      expect(find.text('Próxima'), findsNothing);
    });

    testWidgets('active line with naipe and dinâmica: selo + "Tenor · piano"',
        (tester) async {
      await tester.pumpWidget(_view(_lines, 6000));

      expect(find.byType(VoicePartBadge), findsOneWidget);
      expect(find.text('Tenor · piano'), findsOneWidget);
    });

    testWidgets('naipe only: selo + naipe name; dinâmica only: its text',
        (tester) async {
      const naipeOnly = [
        LyricLine(text: 'Ave', onsetMs: 0, naipe: Naipe.soprano),
      ];
      await tester.pumpWidget(_view(naipeOnly, 100));
      expect(find.byType(VoicePartBadge), findsOneWidget);
      expect(find.text('Soprano'), findsOneWidget);

      const dynamicsOnly = [
        LyricLine(text: 'Ave', onsetMs: 0, dynamics: 'forte')
      ];
      await tester.pumpWidget(_view(dynamicsOnly, 100));
      expect(find.byType(VoicePartBadge), findsNothing);
      expect(find.text('forte'), findsOneWidget);
    });

    testWidgets('the active line is a live region labelled "Linha atual"',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_view(_lines, 6000));

      final node =
          tester.getSemantics(find.bySemanticsLabel(RegExp('Linha atual')));
      expect(node.flagsCollection.isLiveRegion, isTrue);
      expect(node.label, contains('natum de Maria Virgine'));
      handle.dispose();
    });

    testWidgets('renders under the dark theme', (tester) async {
      await tester.pumpWidget(_view(_lines, 6000, theme: AppTheme.dark));

      expect(tester.takeException(), isNull);
      expect(find.text('Tenor · piano'), findsOneWidget);
    });

    testWidgets('360 dp at 130% font: long lines wrap without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const long = [
        LyricLine(text: 'Ave verum corpus natum de Maria Virgine', onsetMs: 0),
        LyricLine(
          text: 'vere passum immolatum in cruce pro homine',
          onsetMs: 4000,
          naipe: Naipe.contralto,
          dynamics: 'crescendo até o forte',
        ),
        LyricLine(text: 'cuius latus perforatum fluxit aqua', onsetMs: 8000),
      ];

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(1.3),
          ),
          child: Scaffold(
            // The screen puts LyricView in its scrollable body.
            body: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LyricView(lines: long, cursor: LyricCursor.at(long, 5000)),
            ),
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
    });
  });
}
