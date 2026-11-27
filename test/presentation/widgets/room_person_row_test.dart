import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/widgets/room_person_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Failure modes (ROOM-12, ROOM-39): the role is missing or glued to the
// name; the screen reader reads name and role as two items; a long name
// pushes the role off screen at 360 dp; the dark theme breaks the row.
Future<void> _pump(WidgetTester tester, String name, {ThemeData? theme}) =>
    tester.pumpWidget(MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: RoomPersonRow(name: name, role: 'Cantor'),
        ),
      ),
    ));

void main() {
  testWidgets('shows the name and the role', (tester) async {
    await _pump(tester, 'Marina');

    expect(find.text('Marina'), findsOneWidget);
    expect(find.text(' · Cantor'), findsOneWidget);
  });

  testWidgets('is one item for the screen reader', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, 'Marina');

    expect(find.bySemanticsLabel('Marina, Cantor'), findsOneWidget);
    expect(find.bySemanticsLabel('Marina'), findsNothing);
    semantics.dispose();
  });

  testWidgets(
      'a long name is cut and the role stays visible at 360 dp in '
      'the dark theme', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _pump(tester, 'Maria Aparecida da Conceição dos Santos Oliveira',
        theme: AppTheme.dark);

    expect(tester.takeException(), isNull);
    final role = tester.getRect(find.text(' · Cantor'));
    expect(role.right, lessThanOrEqualTo(360 - 16));
  });
}
