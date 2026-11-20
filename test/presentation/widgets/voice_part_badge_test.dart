import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/theme/voice_part_colors.dart';
import 'package:cantae/presentation/widgets/voice_part_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {required ThemeData theme}) {
  return MaterialApp(theme: theme, home: Scaffold(body: Center(child: child)));
}

void main() {
  group('VoicePartBadge', () {
    testWidgets('filled variant renders the naipe letter', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const VoicePartBadge(
            variant: VoicePartBadgeVariant.filled,
            part: VoicePart.soprano,
          ),
          theme: AppTheme.light,
        ),
      );

      expect(find.text('S'), findsOneWidget);
    });

    testWidgets('missing variant still renders the naipe letter', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const VoicePartBadge(
            variant: VoicePartBadgeVariant.missing,
            part: VoicePart.tenor,
          ),
          theme: AppTheme.light,
        ),
      );

      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('missing variant renders with a dashed outline, not a solid fill', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const VoicePartBadge(
            variant: VoicePartBadgeVariant.missing,
            part: VoicePart.tenor,
          ),
          theme: AppTheme.light,
        ),
      );

      expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
      final decoratedBox = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox).first,
      );
      final decoration = decoratedBox.decoration as BoxDecoration;
      expect(decoration.color, isNull);
    });

    testWidgets('visitor variant renders "V"', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const VoicePartBadge(variant: VoicePartBadgeVariant.visitor),
          theme: AppTheme.light,
        ),
      );

      expect(find.text('V'), findsOneWidget);
    });

    testWidgets('all variant renders "Todos"', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const VoicePartBadge(variant: VoicePartBadgeVariant.all),
          theme: AppTheme.light,
        ),
      );

      expect(find.text('Todos'), findsOneWidget);
    });

    testWidgets('filled variant uses the naipe color, never color alone (letter present)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const VoicePartBadge(
            variant: VoicePartBadgeVariant.filled,
            part: VoicePart.baixo,
          ),
          theme: AppTheme.light,
        ),
      );

      final decoratedBox = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox).first,
      );
      final decoration = decoratedBox.decoration as BoxDecoration;
      expect(
        decoration.color,
        VoicePartColors.of(VoicePart.baixo, Brightness.light).background,
      );
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('renders under the dark theme without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const VoicePartBadge(
            variant: VoicePartBadgeVariant.filled,
            part: VoicePart.contralto,
          ),
          theme: AppTheme.dark,
        ),
      );

      expect(find.text('C'), findsOneWidget);
    });
  });
}
