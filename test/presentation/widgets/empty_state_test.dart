import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {required ThemeData theme}) {
  return MaterialApp(theme: theme, home: Scaffold(body: child));
}

void main() {
  group('EmptyState', () {
    testWidgets('renders icon, title and message', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EmptyState(
            icon: Icons.library_music,
            title: 'Nenhuma música ainda',
            message: 'Cadastre sua primeira música para começar.',
            primaryLabel: 'Cadastrar primeira música',
            onPrimary: () {},
          ),
          theme: AppTheme.light,
        ),
      );

      expect(find.byIcon(Icons.library_music), findsOneWidget);
      expect(find.text('Nenhuma música ainda'), findsOneWidget);
      expect(
        find.text('Cadastre sua primeira música para começar.'),
        findsOneWidget,
      );
    });

    testWidgets('renders only the primary action when no secondary given', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          EmptyState(
            icon: Icons.library_music,
            title: 'Título',
            message: 'Mensagem',
            primaryLabel: 'Ação primária',
            onPrimary: () {},
          ),
          theme: AppTheme.light,
        ),
      );

      expect(find.text('Ação primária'), findsOneWidget);
      expect(find.text('Ação secundária'), findsNothing);
    });

    testWidgets('renders both actions when a secondary is given', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          EmptyState(
            icon: Icons.library_music,
            title: 'Título',
            message: 'Mensagem',
            primaryLabel: 'Ação primária',
            onPrimary: () {},
            secondaryLabel: 'Ação secundária',
            onSecondary: () {},
          ),
          theme: AppTheme.light,
        ),
      );

      expect(find.text('Ação primária'), findsOneWidget);
      expect(find.text('Ação secundária'), findsOneWidget);
    });

    testWidgets('tapping the primary action fires its callback', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          EmptyState(
            icon: Icons.library_music,
            title: 'Título',
            message: 'Mensagem',
            primaryLabel: 'Ação primária',
            onPrimary: () => tapped = true,
          ),
          theme: AppTheme.light,
        ),
      );

      await tester.tap(find.text('Ação primária'));
      expect(tapped, isTrue);
    });

    testWidgets('tapping the secondary action fires its callback', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          EmptyState(
            icon: Icons.library_music,
            title: 'Título',
            message: 'Mensagem',
            primaryLabel: 'Ação primária',
            onPrimary: () {},
            secondaryLabel: 'Ação secundária',
            onSecondary: () => tapped = true,
          ),
          theme: AppTheme.light,
        ),
      );

      await tester.tap(find.text('Ação secundária'));
      expect(tapped, isTrue);
    });

    testWidgets('renders under the dark theme without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          EmptyState(
            icon: Icons.library_music,
            title: 'Título',
            message: 'Mensagem',
            primaryLabel: 'Ação primária',
            onPrimary: () {},
          ),
          theme: AppTheme.dark,
        ),
      );

      expect(find.text('Título'), findsOneWidget);
    });
  });
}
