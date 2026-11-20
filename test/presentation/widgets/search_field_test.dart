import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/widgets/search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {required ThemeData theme}) {
  return MaterialApp(theme: theme, home: Scaffold(body: child));
}

void main() {
  group('SearchField', () {
    testWidgets('renders the placeholder text', (tester) async {
      await tester.pumpWidget(
        _wrap(SearchField(onChanged: (_) {}), theme: AppTheme.light),
      );

      expect(find.text('Buscar música ou autor'), findsOneWidget);
    });

    testWidgets('typing fires onChanged with the typed text', (tester) async {
      String? received;
      await tester.pumpWidget(
        _wrap(
          SearchField(onChanged: (value) => received = value),
          theme: AppTheme.light,
        ),
      );

      await tester.enterText(find.byType(TextField), 'ave maria');
      expect(received, 'ave maria');
    });

    testWidgets('enabled: false blocks text input', (tester) async {
      var callbackInvoked = false;
      await tester.pumpWidget(
        _wrap(
          SearchField(
            onChanged: (_) => callbackInvoked = true,
            enabled: false,
          ),
          theme: AppTheme.light,
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isFalse);

      await tester.enterText(find.byType(TextField), 'ave maria');
      expect(callbackInvoked, isFalse);
    });

    testWidgets('renders under the dark theme without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(SearchField(onChanged: (_) {}), theme: AppTheme.dark),
      );

      expect(find.text('Buscar música ou autor'), findsOneWidget);
    });

    testWidgets('exposes a search icon', (tester) async {
      await tester.pumpWidget(
        _wrap(SearchField(onChanged: (_) {}), theme: AppTheme.light),
      );

      expect(find.byIcon(Icons.search), findsOneWidget);
    });
  });
}
