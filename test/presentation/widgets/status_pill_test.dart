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

  // Failure modes (ROOM-05): the synced pill uses the neutral colors or
  // literal ones, loses its dot, or stops being a live region.
  group('StatusPill synced', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      testWidgets(
          'uses accentSoft, an accent dot and onAccentSoft text '
          '(${theme.brightness.name})', (tester) async {
        await tester.pumpWidget(_wrap(
          const StatusPill(
            label: 'Visível neste Wi‑Fi',
            variant: StatusPillVariant.synced,
          ),
          theme: theme,
        ));
        final colors = theme.extension<CantaeColors>()!;

        final pill = tester.widget<Material>(find
            .descendant(
                of: find.byType(StatusPill), matching: find.byType(Material))
            .first);
        expect(pill.color, colors.accentSoft);
        final dot = tester
            .widget<Container>(find.byKey(const ValueKey('status-pill-dot')));
        expect((dot.decoration! as BoxDecoration).color, colors.accent);
        final text = tester.widget<Text>(find.text('Visível neste Wi‑Fi'));
        expect(text.style!.color, colors.onAccentSoft);
      });
    }

    testWidgets('is a live region', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const StatusPill(
        label: 'Visível neste Wi‑Fi',
        variant: StatusPillVariant.synced,
      )));

      final node =
          tester.getSemantics(find.bySemanticsLabel('Visível neste Wi‑Fi'));
      expect(node.flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });
  });
}
