import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/widgets/inline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {required ThemeData theme}) {
  return MaterialApp(theme: theme, home: Scaffold(body: child));
}

void main() {
  group('InlineBanner', () {
    testWidgets('renders title and message with no action', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const InlineBanner(
            variant: InlineBannerVariant.info,
            title: 'Título',
            message: 'Mensagem',
          ),
          theme: AppTheme.light,
        ),
      );

      expect(find.text('Título'), findsOneWidget);
      expect(find.text('Mensagem'), findsOneWidget);
    });

    testWidgets('renders a tappable action with button semantics when given', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          InlineBanner(
            variant: InlineBannerVariant.error,
            title: 'Erro',
            message: 'Algo deu errado',
            actionLabel: 'Tentar de novo',
            onAction: () => tapped = true,
          ),
          theme: AppTheme.light,
        ),
      );

      final semantics = tester.getSemantics(find.text('Tentar de novo'));
      expect(semantics.flagsCollection.isButton, isTrue);

      await tester.tap(find.text('Tentar de novo'));
      expect(tapped, isTrue);
    });

    testWidgets('renders all 4 variants in both themes without error', (
      tester,
    ) async {
      for (final variant in InlineBannerVariant.values) {
        for (final theme in [AppTheme.light, AppTheme.dark]) {
          await tester.pumpWidget(
            _wrap(
              InlineBanner(variant: variant, title: 'T', message: 'M'),
              theme: theme,
            ),
          );
          expect(find.text('T'), findsOneWidget);
        }
      }
    });
  });
}
