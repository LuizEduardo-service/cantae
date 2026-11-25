import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/theme/cantae_typography.dart';
import 'package:cantae/presentation/widgets/stat_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child, {ThemeData? theme}) =>
    tester.pumpWidget(MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Scaffold(body: child),
    ));

const _row = Padding(
  padding: EdgeInsets.all(16),
  child: Row(
    children: [
      Expanded(child: StatTile(value: '12', caption: 'ensaios')),
      SizedBox(width: 8),
      Expanded(child: StatTile(value: '1:02:03', caption: 'tempo')),
      SizedBox(width: 8),
      Expanded(child: StatTile(value: '148', caption: 'loops')),
    ],
  ),
);

void main() {
  group('StatTile', () {
    testWidgets('shows the value and the caption', (tester) async {
      await _pump(tester, const StatTile(value: '12', caption: 'ensaios'));

      expect(find.text('12'), findsOneWidget);
      expect(find.text('ensaios'), findsOneWidget);
    });

    testWidgets('the value uses the large mono number style', (tester) async {
      await _pump(tester, const StatTile(value: '12', caption: 'ensaios'));

      final style = tester.widget<Text>(find.text('12')).style!;
      expect(style.fontFamily, CantaeTypography.monoStat.fontFamily);
      expect(style.fontSize, 26);
    });

    testWidgets('reads as one "caption: value" node', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const StatTile(value: '15:35', caption: 'tempo'));

      expect(find.bySemanticsLabel('tempo: 15:35'), findsOneWidget);
      handle.dispose();
    });

    // Regression (rehearsal-history T8): without its own semantics node,
    // tiles side by side in a list item merged into one screen-reader item.
    testWidgets('three in a row are three separate screen-reader items',
        (tester) async {
      final handle = tester.ensureSemantics();
      // Inside a list item, as on the History screen: that is where the
      // tiles merged.
      await _pump(tester, ListView(children: const [_row]));

      expect(find.bySemanticsLabel('ensaios: 12'), findsOneWidget);
      expect(find.bySemanticsLabel('tempo: 1:02:03'), findsOneWidget);
      expect(find.bySemanticsLabel('loops: 148'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('renders under the dark theme', (tester) async {
      await _pump(tester, _row, theme: AppTheme.dark);

      expect(tester.takeException(), isNull);
      expect(find.text('148'), findsOneWidget);
    });

    testWidgets('three in a row fit 360 dp at 130 % font', (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await _pump(tester, _row);

      expect(tester.takeException(), isNull);
      expect(find.text('1:02:03'), findsOneWidget);
    });
  });
}
