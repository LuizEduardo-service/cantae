import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/theme/cantae_colors.dart';
import 'package:cantae/presentation/theme/cantae_spacing.dart';
import 'package:cantae/presentation/widgets/room_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Failure modes (ROOM-23, ROOM-28, ROOM-29): the tile shows a code or
// misses the master or the song; a room without a song shows nothing;
// the chosen room is not marked; a disabled tile still reacts; the screen
// reader reads parts separately or not as a button; the tile is too small
// or overflows at 360 dp with a large font; the dark theme breaks it.
Future<void> _pump(
  WidgetTester tester, {
  String? song = 'Ave Verum Corpus',
  bool selected = false,
  VoidCallback? onTap,
  ThemeData? theme,
  double textScale = 1,
}) =>
    tester.pumpWidget(MaterialApp(
      theme: theme ?? AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: RoomTile(
              masterName: 'Marina Conceição dos Santos',
              songName: song,
              selected: selected,
              onTap: onTap,
            ),
          ),
        ),
      ),
    ));

ShapeBorder _shape(WidgetTester tester) => tester
    .widget<Material>(find
        .descendant(of: find.byType(RoomTile), matching: find.byType(Material))
        .first)
    .shape!;

void main() {
  testWidgets('shows the master and the song, no code (ROOM-23)',
      (tester) async {
    await _pump(tester, onTap: () {});

    expect(find.text('Sala de Marina Conceição dos Santos'), findsOneWidget);
    expect(find.text('Ave Verum Corpus'), findsOneWidget);
    expect(find.textContaining(RegExp(r'\d{4}')), findsNothing);
  });

  testWidgets('a room without a song says so', (tester) async {
    await _pump(tester, song: null, onTap: () {});

    expect(find.text('Sem música escolhida'), findsOneWidget);
  });

  testWidgets('the chosen room has a 2 px accent border (ROOM-28)',
      (tester) async {
    final accent = AppTheme.light.extension<CantaeColors>()!.accent;
    await _pump(tester, selected: true, onTap: () {});
    final side = (_shape(tester) as RoundedRectangleBorder).side;
    expect(side.color, accent);
    expect(side.width, 2);

    await _pump(tester, onTap: () {});
    expect(
        (_shape(tester) as RoundedRectangleBorder).side.color, isNot(accent));
  });

  testWidgets('a tap calls back; a disabled tile ignores taps (ROOM-29)',
      (tester) async {
    var taps = 0;
    await _pump(tester, onTap: () => taps++);
    await tester.tap(find.byType(RoomTile));
    expect(taps, 1);

    await _pump(tester);
    await tester.tap(find.byType(RoomTile));
    expect(taps, 1);
  });

  testWidgets('is one button for the screen reader', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, selected: true, onTap: () {});

    final node = tester.getSemantics(find.bySemanticsLabel(
        'Sala de Marina Conceição dos Santos, Ave Verum Corpus'));
    final flags = node.getSemanticsData().flagsCollection;
    expect(flags.isButton, isTrue);
    expect(flags.isSelected.toBoolOrNull(), isTrue);
    semantics.dispose();
  });

  testWidgets('is at least 44 dp and fits 360 dp at 130 % in the dark theme',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _pump(tester, theme: AppTheme.dark, textScale: 1.3, onTap: () {});

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(RoomTile)).height,
        greaterThanOrEqualTo(CantaeSpacing.minTouchTarget));
  });
}
