import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/theme/cantae_colors.dart';
import 'package:cantae/presentation/widgets/mute_solo_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {ThemeData? theme}) => MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    );

BoxDecoration _decoration(WidgetTester tester) => tester
    .widget<Container>(find.descendant(
      of: find.byType(MuteSoloToggle),
      matching: find.byType(Container),
    ))
    .decoration! as BoxDecoration;

void main() {
  group('MuteSoloToggle', () {
    testWidgets('off: field background and the short label', (tester) async {
      await tester.pumpWidget(_wrap(MuteSoloToggle(
        label: 'M',
        semanticLabel: 'Mudo',
        active: false,
        onTap: () {},
      )));
      final colors = AppTheme.light.extension<CantaeColors>()!;

      expect(find.text('M'), findsOneWidget);
      expect(_decoration(tester).color, colors.fillField);
    });

    testWidgets('on: accentSoft background', (tester) async {
      await tester.pumpWidget(_wrap(MuteSoloToggle(
        label: 'S',
        semanticLabel: 'Solo',
        active: true,
        onTap: () {},
      )));
      final colors = AppTheme.light.extension<CantaeColors>()!;

      expect(_decoration(tester).color, colors.accentSoft);
    });

    testWidgets('tapping calls onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(MuteSoloToggle(
        label: 'M',
        semanticLabel: 'Mudo',
        active: false,
        onTap: () => taps++,
      )));

      await tester.tap(find.byType(MuteSoloToggle));

      expect(taps, 1);
    });

    testWidgets('state is announced, not only shown by color (RNF-UX-05)',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(MuteSoloToggle(
        label: 'M',
        semanticLabel: 'Mudo',
        active: true,
        onTap: () {},
      )));

      final node = tester.getSemantics(find.bySemanticsLabel(RegExp('Mudo')));
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isToggled.toBoolOrNull(), isTrue);

      await tester.pumpWidget(_wrap(MuteSoloToggle(
        label: 'M',
        semanticLabel: 'Mudo',
        active: false,
        onTap: () {},
      )));
      final off = tester.getSemantics(find.bySemanticsLabel(RegExp('Mudo')));
      expect(off.flagsCollection.isToggled.toBoolOrNull(), isFalse);
      handle.dispose();
    });

    testWidgets('touch target is at least 44 dp', (tester) async {
      await tester.pumpWidget(_wrap(MuteSoloToggle(
        label: 'M',
        semanticLabel: 'Mudo',
        active: false,
        onTap: () {},
      )));

      final size = tester.getSize(find.byType(MuteSoloToggle));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('renders under the dark theme with its tokens', (tester) async {
      await tester.pumpWidget(_wrap(
        MuteSoloToggle(
          label: 'S',
          semanticLabel: 'Solo',
          active: true,
          onTap: () {},
        ),
        theme: AppTheme.dark,
      ));
      final colors = AppTheme.dark.extension<CantaeColors>()!;

      expect(tester.takeException(), isNull);
      expect(_decoration(tester).color, colors.accentSoft);
    });
  });
}
