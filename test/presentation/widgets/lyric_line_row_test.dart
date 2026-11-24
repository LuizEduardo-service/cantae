import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/presentation/providers/lyrics_editor_notifier.dart';
import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/theme/cantae_colors.dart';
import 'package:cantae/presentation/widgets/lyric_line_row.dart';
import 'package:cantae/presentation/widgets/segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Calls {
  int toggles = 0;
  final List<String> texts = [];
  final List<Naipe?> naipes = [];
  final List<String?> dynamics = [];
}

Widget _row(
  LyricDraftLine line, {
  bool expanded = false,
  bool isCurrent = false,
  _Calls? calls,
  ThemeData? theme,
}) {
  final c = calls ?? _Calls();
  return MaterialApp(
    theme: theme ?? AppTheme.light,
    home: Scaffold(
      body: SingleChildScrollView(
        child: LyricLineRow(
          line: line,
          isCurrent: isCurrent,
          expanded: expanded,
          onToggleExpanded: () => c.toggles++,
          onTextChanged: c.texts.add,
          onNaipeChanged: c.naipes.add,
          onDynamicsChanged: c.dynamics.add,
        ),
      ),
    ),
  );
}

Future<void> _blur(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
}

Finder _field(String hint) => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == hint,
    );

String _fieldText(WidgetTester tester, String hint) =>
    tester.widget<TextField>(_field(hint)).controller!.text;

BoxDecoration _cardDecoration(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.byKey(const ValueKey('lyric-line-card')),
  );
  return container.decoration! as BoxDecoration;
}

void main() {
  group('LyricLineRow collapsed (LYR-09, LYR-16)', () {
    testWidgets(
        'shows time in mm:ss.s, text, naipe selo and "Naipe · dinâmica"',
        (tester) async {
      await tester.pumpWidget(_row(const LyricDraftLine(
        text: 'Ave verum corpus',
        onsetMs: 5300,
        naipe: Naipe.tenor,
        dynamics: 'piano',
      )));

      expect(find.text('0:05.3'), findsOneWidget);
      expect(find.text('Ave verum corpus'), findsOneWidget);
      expect(find.text('T'), findsOneWidget);
      expect(find.text('Tenor · piano'), findsOneWidget);
      expect(find.text('Editar'), findsOneWidget);
      expect(_field('Texto da linha'), findsNothing);
    });

    testWidgets('unmarked line shows "—"; naipe without dinâmica is selo only',
        (tester) async {
      await tester.pumpWidget(_row(const LyricDraftLine(
        text: 'natum de Maria Virgine',
        naipe: Naipe.soprano,
      )));

      expect(find.text('—'), findsOneWidget);
      expect(find.text('S'), findsOneWidget);
      expect(find.textContaining('Soprano'), findsNothing);
    });

    testWidgets('a line with no text yet shows a placeholder', (tester) async {
      await tester.pumpWidget(_row(const LyricDraftLine(text: '')));

      expect(find.text('Linha sem texto'), findsOneWidget);
    });

    testWidgets('tapping "Editar" asks to expand, with a 44 dp target',
        (tester) async {
      final calls = _Calls();
      await tester.pumpWidget(
        _row(const LyricDraftLine(text: 'Ave'), calls: calls),
      );

      final size = tester.getSize(find.ancestor(
        of: find.text('Editar'),
        matching: find.byType(InkWell),
      ));
      expect(size.height, greaterThanOrEqualTo(44));

      await tester.tap(find.text('Editar'));
      expect(calls.toggles, 1);
    });
  });

  group('LyricLineRow expanded (LYR-02, LYR-14, LYR-15)', () {
    testWidgets('shows texto, naipe selector (4 naipes + Nenhum) and dinâmica',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_row(
        const LyricDraftLine(text: 'Ave', naipe: Naipe.contralto),
        expanded: true,
      ));

      expect(_fieldText(tester, 'Texto da linha'), 'Ave');
      expect(_field('Dinâmica (opcional)'), findsOneWidget);
      for (final label in [
        'Soprano',
        'Contralto',
        'Tenor',
        'Baixo',
        'Nenhum'
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      final selected = tester.getSemantics(find.bySemanticsLabel('Contralto'));
      expect(selected.flagsCollection.isSelected.toBoolOrNull(), isTrue);
      expect(find.text('Concluir'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('choosing a naipe or "Nenhum" reports it', (tester) async {
      final calls = _Calls();
      await tester.pumpWidget(_row(
        const LyricDraftLine(text: 'Ave', naipe: Naipe.soprano),
        expanded: true,
        calls: calls,
      ));

      Finder segment(String label) => find.descendant(
            of: find.byType(SegmentedControl<Naipe?>),
            matching: find.text(label),
          );
      await tester.tap(segment('B'));
      await tester.tap(segment('—'));

      expect(calls.naipes, [Naipe.bass, null]);
    });

    testWidgets('valid text is reported; empty text is not and reverts on blur',
        (tester) async {
      final calls = _Calls();
      await tester.pumpWidget(_row(
        const LyricDraftLine(text: 'Ave'),
        expanded: true,
        calls: calls,
      ));

      await tester.enterText(_field('Texto da linha'), 'Ave verum');
      expect(calls.texts, ['Ave verum']);

      await tester.enterText(_field('Texto da linha'), '');
      expect(calls.texts, ['Ave verum']);

      await _blur(tester);
      expect(_fieldText(tester, 'Texto da linha'), 'Ave');
    });

    testWidgets('text over 200 chars is not reported and reverts on blur',
        (tester) async {
      final calls = _Calls();
      await tester.pumpWidget(_row(
        const LyricDraftLine(text: 'Ave'),
        expanded: true,
        calls: calls,
      ));

      await tester.enterText(_field('Texto da linha'), 'x' * 201);
      expect(calls.texts, isEmpty);

      await _blur(tester);
      expect(_fieldText(tester, 'Texto da linha'), 'Ave');
    });

    testWidgets('dinâmica: valid reported, over 40 reverts, empty clears',
        (tester) async {
      final calls = _Calls();
      await tester.pumpWidget(_row(
        const LyricDraftLine(text: 'Ave', dynamics: 'forte'),
        expanded: true,
        calls: calls,
      ));
      final field = _field('Dinâmica (opcional)');

      await tester.enterText(field, 'x' * 41);
      expect(calls.dynamics, isEmpty);
      await _blur(tester);
      expect(_fieldText(tester, 'Dinâmica (opcional)'), 'forte');

      await tester.enterText(field, 'piano');
      await tester.enterText(field, '');
      expect(calls.dynamics, ['piano', null]);
    });
  });

  group('LyricLineRow current line (LYR-13)', () {
    testWidgets('current line gets an accent border, bolder text and a label',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_row(
        const LyricDraftLine(text: 'Ave verum corpus', onsetMs: 1000),
        isCurrent: true,
      ));
      final colors = AppTheme.light.extension<CantaeColors>()!;

      final border = _cardDecoration(tester).border! as Border;
      expect(border.top.color, colors.accent);
      expect(border.top.width, 2);
      final text = tester.widget<Text>(find.text('Ave verum corpus'));
      expect(text.style!.fontWeight, FontWeight.w600);
      expect(find.bySemanticsLabel(RegExp('Linha atual')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a line that is not current has the regular divider border',
        (tester) async {
      await tester.pumpWidget(_row(
        const LyricDraftLine(text: 'Ave verum corpus', onsetMs: 1000),
      ));
      final colors = AppTheme.light.extension<CantaeColors>()!;

      final border = _cardDecoration(tester).border! as Border;
      expect(border.top.color, colors.divider);
      expect(border.top.width, 1);
    });
  });

  group('LyricLineRow at 360 dp with 130% system font (AGENTS.md §5)', () {
    testWidgets('collapsed and expanded lay out without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      Widget scaled(Widget child) => MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(1.3),
            ),
            child: child,
          );
      const line = LyricDraftLine(
        text: 'vere passum immolatum in cruce pro homine',
        onsetMs: 125300,
        naipe: Naipe.contralto,
        dynamics: 'mezzo-piano',
      );

      await tester.pumpWidget(scaled(_row(line)));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(scaled(_row(line, expanded: true)));
      expect(tester.takeException(), isNull);
    });
  });

  group('LyricLineRow themes', () {
    testWidgets('renders collapsed and expanded under the dark theme',
        (tester) async {
      final colors = AppTheme.dark.extension<CantaeColors>()!;
      await tester.pumpWidget(_row(
        const LyricDraftLine(
          text: 'Ave',
          onsetMs: 0,
          naipe: Naipe.bass,
          dynamics: 'forte',
        ),
        theme: AppTheme.dark,
      ));
      expect(_cardDecoration(tester).color, colors.surface);
      expect(find.text('Baixo · forte'), findsOneWidget);

      await tester.pumpWidget(_row(
        const LyricDraftLine(text: 'Ave'),
        expanded: true,
        theme: AppTheme.dark,
      ));
      expect(tester.takeException(), isNull);
      expect(_field('Texto da linha'), findsOneWidget);
    });
  });
}
