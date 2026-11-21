import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/widgets/toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Toast', () {
    testWidgets('show inserts the message into the tree', (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      Toast.show(capturedContext, 'Atrasos salvos');
      await tester.pump();

      expect(find.text('Atrasos salvos'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2600));
    });

    testWidgets('disappears on its own after ~2.5s', (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      Toast.show(capturedContext, 'Atrasos salvos');
      await tester.pump();
      expect(find.text('Atrasos salvos'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2600));

      expect(find.text('Atrasos salvos'), findsNothing);
    });

    testWidgets('renders under the dark theme without throwing', (
      tester,
    ) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      Toast.show(capturedContext, 'Atrasos salvos');
      await tester.pump();

      expect(find.text('Atrasos salvos'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2600));
    });
  });
}
