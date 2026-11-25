import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/theme/cantae_colors.dart';
import 'package:cantae/presentation/widgets/status_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {ThemeData? theme}) => MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('StatusPill (neutral)', () {
    testWidgets('renders its label on the muted fill', (tester) async {
      await tester
          .pumpWidget(_wrap(const StatusPill(label: 'Funciona offline')));
      final colors = AppTheme.light.extension<CantaeColors>()!;

      expect(find.text('Funciona offline'), findsOneWidget);
      final material = tester.widget<Material>(find.descendant(
        of: find.byType(StatusPill),
        matching: find.byType(Material),
      ));
      expect(material.color, colors.fillMuted);
    });

    testWidgets('is 44 dp tall', (tester) async {
      await tester
          .pumpWidget(_wrap(const StatusPill(label: 'Funciona offline')));

      expect(tester.getSize(find.byType(StatusPill)).height, 44);
    });

    testWidgets('is a live region for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await tester
          .pumpWidget(_wrap(const StatusPill(label: 'Funciona offline')));

      final node =
          tester.getSemantics(find.bySemanticsLabel('Funciona offline'));
      expect(node.flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });

    testWidgets('renders under the dark theme with its tokens', (tester) async {
      await tester.pumpWidget(_wrap(
        const StatusPill(label: 'Funciona offline'),
        theme: AppTheme.dark,
      ));
      final colors = AppTheme.dark.extension<CantaeColors>()!;

      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.text('Funciona offline'));
      expect(text.style!.color, colors.text2);
    });
  });
}
