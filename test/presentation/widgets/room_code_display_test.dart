import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/theme/cantae_spacing.dart';
import 'package:cantae/presentation/theme/cantae_typography.dart';
import 'package:cantae/presentation/widgets/room_code_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Failure modes (ROOM-05, ROOM-06): the code is not in the mono style;
// "Copiar" copies nothing or something else, or gives no feedback; the
// screen reader reads the code as one number; the button is too small;
// the dark theme breaks the card; a large font cuts the code at 360 dp.
Future<void> _pump(
  WidgetTester tester, {
  ThemeData? theme,
  double textScale = 1,
}) =>
    tester.pumpWidget(MaterialApp(
      theme: theme ?? AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: RoomCodeDisplay(code: '4827'),
          ),
        ),
      ),
    ));

void main() {
  testWidgets('shows the code in the large mono style (ROOM-05)',
      (tester) async {
    await _pump(tester);

    final style = tester.widget<Text>(find.text('4827')).style!;
    expect(style.fontFamily, CantaeTypography.monoLarge.fontFamily);
    expect(style.fontSize, CantaeTypography.monoLarge.fontSize);
    expect(find.text('Código da sala'), findsOneWidget);
  });

  testWidgets('"Copiar" puts the code in the clipboard and says so (ROOM-06)',
      (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await _pump(tester);

    await tester.tap(find.text('Copiar'));
    await tester.pump();

    expect(copied, ['4827']);
    expect(find.text('Código copiado'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('the screen reader reads the code digit by digit',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);

    expect(find.bySemanticsLabel('Código da sala 4 8 2 7'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('"Copiar" is at least 44 dp tall', (tester) async {
    await _pump(tester);

    expect(
      tester
          .getSize(find.ancestor(
              of: find.text('Copiar'), matching: find.byType(InkWell)))
          .height,
      greaterThanOrEqualTo(CantaeSpacing.minTouchTarget),
    );
  });

  testWidgets('fits 360 dp at 130 % in the dark theme', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _pump(tester, theme: AppTheme.dark, textScale: 1.3);

    expect(tester.takeException(), isNull);
    expect(find.text('4827'), findsOneWidget);
  });
}
