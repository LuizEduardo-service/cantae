import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/theme/cantae_colors.dart';
import 'package:cantae/presentation/theme/cantae_spacing.dart';
import 'package:cantae/presentation/theme/cantae_typography.dart';
import 'package:cantae/presentation/widgets/code_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Failure modes (ROOM-26, ROOM-27): letters or a 5th digit get in; the
// error border does not show (or shows when there is no error); a
// disabled field still takes typing; the screen reader does not say what
// the field is; the dark theme breaks the field.
Future<TextEditingController> _pump(
  WidgetTester tester, {
  bool hasError = false,
  bool enabled = true,
  ThemeData? theme,
}) async {
  final controller = TextEditingController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(MaterialApp(
    theme: theme ?? AppTheme.light,
    home: Scaffold(
      body: CodeInput(
        controller: controller,
        hasError: hasError,
        enabled: enabled,
      ),
    ),
  ));
  return controller;
}

OutlineInputBorder _enabledBorder(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).decoration!.enabledBorder!
        as OutlineInputBorder;

void main() {
  testWidgets('keeps digits only, at most 4 (ROOM-27)', (tester) async {
    final controller = await _pump(tester);

    await tester.enterText(find.byType(TextField), '4a8 2-75');

    expect(controller.text, '4827');
  });

  testWidgets('uses the mono input style', (tester) async {
    await _pump(tester);

    final style = tester.widget<TextField>(find.byType(TextField)).style!;
    expect(style.fontFamily, CantaeTypography.monoInput.fontFamily);
    expect(style.fontSize, 28);
  });

  testWidgets('shows the error border only on error (ROOM-26)', (tester) async {
    await _pump(tester, hasError: true);
    final danger = AppTheme.light.extension<CantaeColors>()!.dangerSolid;
    expect(_enabledBorder(tester).borderSide.color, danger);
    expect(_enabledBorder(tester).borderSide.width, 2);

    await _pump(tester);
    expect(_enabledBorder(tester).borderSide.color, isNot(danger));
  });

  testWidgets('a disabled field takes no typing', (tester) async {
    final controller = await _pump(tester, enabled: false);

    await tester.enterText(find.byType(TextField), '12');

    expect(controller.text, isEmpty);
  });

  testWidgets('the screen reader names the field', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);

    expect(find.bySemanticsLabel(RegExp('Código da sala')), findsWidgets);
    semantics.dispose();
  });

  testWidgets('is at least 44 dp tall in the dark theme', (tester) async {
    await _pump(tester, theme: AppTheme.dark);

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(TextField)).height,
        greaterThanOrEqualTo(CantaeSpacing.minTouchTarget));
  });
}
