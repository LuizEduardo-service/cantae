import 'package:cantae/presentation/screens/coming_soon/coming_soon_screen.dart';
import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {required ThemeData theme}) {
  return MaterialApp(theme: theme, home: child);
}

void main() {
  group('ComingSoonScreen', () {
    testWidgets('renders the given title and a Voltar back pill', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const ComingSoonScreen(title: 'Entrar em sala'),
          theme: AppTheme.light,
        ),
      );

      expect(find.text('Entrar em sala'), findsOneWidget);
      expect(find.text('‹ Voltar'), findsOneWidget);
      expect(find.text('Em breve'), findsOneWidget);
    });

    testWidgets('renders with an arbitrary different title', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ComingSoonScreen(title: 'Perfil'),
          theme: AppTheme.light,
        ),
      );

      expect(find.text('Perfil'), findsOneWidget);
    });

    testWidgets('renders under the dark theme without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const ComingSoonScreen(title: 'Criar sala'),
          theme: AppTheme.dark,
        ),
      );

      expect(find.text('Criar sala'), findsOneWidget);
    });
  });
}
