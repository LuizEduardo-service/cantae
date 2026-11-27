import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/theme/cantae_spacing.dart';
import 'package:cantae/presentation/widgets/join_request_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Failure modes (ROOM-11, ROOM-14, ROOM-54): the buttons call the wrong
// callback; the screen reader says "Aprovar" without saying whom; with the
// room full "Aprovar" still works or nothing says why; the buttons are
// too small; a large font overflows at 360 dp; the dark theme breaks it.
Future<List<String>> _pump(
  WidgetTester tester, {
  bool roomFull = false,
  ThemeData? theme,
  double textScale = 1,
}) async {
  final calls = <String>[];
  await tester.pumpWidget(MaterialApp(
    theme: theme ?? AppTheme.light,
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: JoinRequestRow(
            name: 'Marina',
            roomFull: roomFull,
            onReject: () => calls.add('reject'),
            onApprove: () => calls.add('approve'),
          ),
        ),
      ),
    ),
  ));
  return calls;
}

void main() {
  testWidgets('shows the name and calls each action (ROOM-11)', (tester) async {
    final calls = await _pump(tester);

    expect(find.text('Marina'), findsOneWidget);
    await tester.tap(find.text('Recusar'));
    await tester.tap(find.text('Aprovar'));

    expect(calls, ['reject', 'approve']);
  });

  testWidgets('the screen reader names the person on each button',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final calls = await _pump(tester);

    final approve =
        tester.getSemantics(find.bySemanticsLabel('Aprovar Marina'));
    expect(approve.getSemanticsData().flagsCollection.isButton, isTrue);
    expect(find.bySemanticsLabel('Recusar Marina'), findsOneWidget);
    tester.semantics.tap(find.semantics.byLabel('Aprovar Marina'));
    expect(calls, ['approve']);
    semantics.dispose();
  });

  testWidgets(
      'with the room full, "Aprovar" is off and the row says why '
      '(ROOM-14)', (tester) async {
    final semantics = tester.ensureSemantics();
    final calls = await _pump(tester, roomFull: true);

    await tester.tap(find.text('Aprovar'));
    expect(calls, isEmpty);
    expect(find.text('Sala cheia: 8 de 8.'), findsOneWidget);
    final sentence = tester
        .getSemantics(find.text('Sala cheia: 8 de 8.'))
        .getSemanticsData();
    expect(sentence.flagsCollection.isLiveRegion, isTrue);
    await tester.tap(find.text('Recusar'));
    expect(calls, ['reject']);
    semantics.dispose();
  });

  testWidgets('buttons are 44 dp; fits 360 dp at 130 % in the dark theme',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _pump(tester, roomFull: true, theme: AppTheme.dark, textScale: 1.3);

    expect(tester.takeException(), isNull);
    for (final label in ['Recusar', 'Aprovar']) {
      final button =
          find.ancestor(of: find.text(label), matching: find.byType(InkWell));
      expect(tester.getSize(button).height,
          greaterThanOrEqualTo(CantaeSpacing.minTouchTarget));
    }
  });
}
