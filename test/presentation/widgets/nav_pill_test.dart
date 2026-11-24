import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/theme/cantae_colors.dart';
import 'package:cantae/presentation/widgets/nav_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {required ThemeData theme}) {
  return MaterialApp(theme: theme, home: Scaffold(body: Center(child: child)));
}

void main() {
  group('NavPill', () {
    testWidgets('back variant renders the chevron prefix and label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          NavPill(
            variant: NavPillVariant.back,
            label: 'Biblioteca',
            onTap: () {},
          ),
          theme: AppTheme.light,
        ),
      );

      expect(find.text('‹ Biblioteca'), findsOneWidget);
    });

    testWidgets('exit variant renders its label with no prefix', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          NavPill(variant: NavPillVariant.exit, label: 'Sair', onTap: () {}),
          theme: AppTheme.light,
        ),
      );

      expect(find.text('Sair'), findsOneWidget);
    });

    testWidgets('cancel variant renders its label with no prefix', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          NavPill(
            variant: NavPillVariant.cancel,
            label: 'Cancelar',
            onTap: () {},
          ),
          theme: AppTheme.light,
        ),
      );

      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('action variant renders its label with no prefix', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          NavPill(
            variant: NavPillVariant.action,
            label: 'Importar',
            onTap: () {},
          ),
          theme: AppTheme.light,
        ),
      );

      expect(find.text('Importar'), findsOneWidget);
    });

    testWidgets('exposes a button semantics role for every variant', (
      tester,
    ) async {
      for (final variant in NavPillVariant.values) {
        await tester.pumpWidget(
          _wrap(
            NavPill(variant: variant, label: 'Rótulo', onTap: () {}),
            theme: AppTheme.light,
          ),
        );

        final semantics = tester.getSemantics(find.byType(NavPill));
        expect(
          semantics.flagsCollection.isButton,
          isTrue,
          reason: 'variant $variant should expose the button semantics flag',
        );
      }
    });

    testWidgets('tap callback fires for every variant', (tester) async {
      for (final variant in NavPillVariant.values) {
        var tapped = false;
        await tester.pumpWidget(
          _wrap(
            NavPill(
              variant: variant,
              label: 'Rótulo',
              onTap: () => tapped = true,
            ),
            theme: AppTheme.light,
          ),
        );

        await tester.tap(find.byType(NavPill));
        await tester.pump();

        expect(tapped, isTrue, reason: 'variant $variant should fire onTap');
      }
    });

    testWidgets('null onTap renders a disabled pill: muted text, not enabled',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const NavPill(
            variant: NavPillVariant.action,
            label: 'Ouvir com a letra',
            onTap: null,
          ),
          theme: AppTheme.light,
        ),
      );
      final colors = AppTheme.light.extension<CantaeColors>()!;

      final text = tester.widget<Text>(find.text('Ouvir com a letra'));
      expect(text.style!.color, colors.textDisabled);
      final semantics = tester.getSemantics(find.text('Ouvir com a letra'));
      expect(semantics.flagsCollection.isEnabled.toBoolOrNull(), isFalse);
      handle.dispose();
    });

    testWidgets('renders under the dark theme without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          NavPill(
            variant: NavPillVariant.action,
            label: 'Importar',
            onTap: () {},
          ),
          theme: AppTheme.dark,
        ),
      );

      expect(find.text('Importar'), findsOneWidget);
    });

    testWidgets('meets the minimum 44x44 touch target', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NavPill(
            variant: NavPillVariant.action,
            label: 'Importar',
            onTap: () {},
          ),
          theme: AppTheme.light,
        ),
      );

      final size = tester.getSize(find.byType(NavPill));
      expect(size.height, greaterThanOrEqualTo(44));
      expect(size.width, greaterThanOrEqualTo(44));
    });
  });
}
