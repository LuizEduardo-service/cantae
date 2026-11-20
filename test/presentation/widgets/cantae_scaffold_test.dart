import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/widgets/cantae_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {required ThemeData theme}) {
  return MaterialApp(theme: theme, home: child);
}

void main() {
  group('CantaeScaffold', () {
    testWidgets('renders top slots and body, no footer', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CantaeScaffold(
            topLeft: const Text('Biblioteca'),
            topRight: const Text('Importar'),
            body: const Text('conteudo'),
          ),
          theme: AppTheme.light,
        ),
      );

      expect(find.text('Biblioteca'), findsOneWidget);
      expect(find.text('Importar'), findsOneWidget);
      expect(find.text('conteudo'), findsOneWidget);
      expect(find.byType(CantaeScaffold), findsOneWidget);
    });

    testWidgets('renders a footer when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CantaeScaffold(
            body: const Text('conteudo'),
            footer: const Text('rodape'),
          ),
          theme: AppTheme.light,
        ),
      );

      expect(find.text('rodape'), findsOneWidget);
    });

    testWidgets('omits the footer slot entirely when not provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(CantaeScaffold(body: const Text('conteudo')), theme: AppTheme.light),
      );

      expect(find.text('rodape'), findsNothing);
    });

    testWidgets('respects the device safe area via a SafeArea ancestor', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(CantaeScaffold(body: const Text('conteudo')), theme: AppTheme.light),
      );

      final safeAreaFinder = find.ancestor(
        of: find.text('conteudo'),
        matching: find.byType(SafeArea),
      );
      expect(safeAreaFinder, findsOneWidget);
    });

    testWidgets('renders under the dark theme without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CantaeScaffold(
            topLeft: const Text('Biblioteca'),
            body: const Text('conteudo'),
            footer: const Text('rodape'),
          ),
          theme: AppTheme.dark,
        ),
      );

      expect(find.text('Biblioteca'), findsOneWidget);
      expect(find.text('conteudo'), findsOneWidget);
      expect(find.text('rodape'), findsOneWidget);
    });
  });
}
