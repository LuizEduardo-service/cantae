import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/theme/cantae_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'MaterialApp resolves CantaeColors.accent to the light value under ThemeMode.light',
    (tester) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.light,
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final accent = Theme.of(capturedContext).extension<CantaeColors>()!.accent;
      expect(accent, const Color(0xFF0E5E4B));
    },
  );

  testWidgets(
    'MaterialApp resolves CantaeColors.accent to the dark value under ThemeMode.dark',
    (tester) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final accent = Theme.of(capturedContext).extension<CantaeColors>()!.accent;
      expect(accent, const Color(0xFF5FC4A3));
    },
  );

  testWidgets(
    'a Text widget using the Geist-family body style resolves that font family at runtime',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Text('ensaio', key: Key('probe')),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.byKey(const Key('probe')));
      final context = tester.element(find.byKey(const Key('probe')));
      final effectiveStyle = DefaultTextStyle.of(context).style.merge(textWidget.style);

      expect(effectiveStyle.fontFamily, 'Geist');
    },
  );
}
