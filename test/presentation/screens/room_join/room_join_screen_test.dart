import 'package:cantae/domain/session/ids.dart';
import 'package:cantae/domain/session/room_entry_rules.dart';
import 'package:cantae/presentation/providers/active_room_notifier.dart';
import 'package:cantae/presentation/providers/join_room_notifier.dart';
import 'package:cantae/presentation/providers/room_providers.dart';
import 'package:cantae/presentation/screens/room_join/room_join_screen.dart';
import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/widgets/code_input.dart';
import 'package:cantae/presentation/widgets/room_tile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../fixtures/room_fakes.dart';

// Failure modes (UI_SPEC §6.8; ROOM-01, 22..38, 51, 52, 55..58):
// - searching starts before the person has a name; closing the name sheet
//   leaves an empty screen;
// - a phase shows the wrong title, no action, or an action that does
//   something else; the iOS hint shows on Android or is missing on iOS;
// - tapping a tile does not mark it or does not say whose code to type;
// - "Código não encontrado" has no error border, and "Digitar de novo"
//   keeps the old code;
// - while waiting, the tiles and the field still react;
// - a granted request does not open the singer's room;
// - typing does not reach the state; "Entrar" works with fewer than 4;
// - banners are not announced; the footer is missing; the screen breaks
//   in the dark theme or at 360 dp with 130 % font.
const _marina = RoomTileView(
    id: RoomId('marina'), masterName: 'Marina', songName: 'Ave Verum Corpus');
const _bruno = RoomTileView(id: RoomId('bruno'), masterName: 'Bruno');

class _FakeJoin extends JoinRoomNotifier {
  _FakeJoin(super.ref, this.next);

  final JoinRoomState next;
  final calls = <String>[];

  void set(JoinRoomState s) => state = s;

  @override
  Future<void> start({required String displayName}) async {
    calls.add('start:$displayName');
    state = next;
  }

  @override
  Future<void> searchAgain() async => calls.add('searchAgain');
  @override
  void selectRoom(RoomId id) {
    calls.add('select:${id.value}');
    state = state.copyWith(selected: id);
  }

  @override
  void setCode(String raw) {
    calls.add('code:$raw');
    state = state.copyWith(code: raw);
  }

  @override
  Future<void> submitCode() async => calls.add('submit');
  @override
  Future<void> cancelRequest() async => calls.add('cancel');
  @override
  void dismissOutcome() {
    calls.add('dismiss');
    state = state.copyWith(phase: JoinPhase.searching, code: '');
  }

  @override
  Future<void> retry() async => calls.add('retry');
  @override
  Future<void> openSettings() async => calls.add('settings');
}

JoinRoomState _phase(
  JoinPhase phase, {
  JoinOutcome? outcome,
  List<RoomTileView> rooms = const [_marina, _bruno],
  RoomTileView? target,
  String code = '',
}) =>
    JoinRoomState(
      phase: phase,
      outcome: outcome,
      rooms: rooms,
      target: target,
      code: code,
    );

void main() {
  late InMemoryLocalProfiles profiles;
  late _FakeJoin join;

  setUp(() => profiles = InMemoryLocalProfiles('ana', displayName: 'Ana'));

  Future<void> pump(
    WidgetTester tester,
    JoinRoomState next, {
    ThemeData? theme,
    double textScale = 1,
  }) async {
    if (tester.view.physicalSize.width != 360) {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          name: 'library',
          builder: (_, __) => const Text('route:library'),
          routes: [
            GoRoute(
              path: 'room/join',
              name: 'room-join',
              builder: (_, __) => const RoomJoinScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/room/member',
          name: 'room-member',
          builder: (_, __) => const Text('route:room-member'),
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        localProfileRepositoryProvider.overrideWithValue(profiles),
        activeRoomProvider.overrideWith((ref) => ActiveRoomNotifier(
              newController: (_) => throw UnimplementedError(),
              profiles: profiles,
            )),
        joinRoomProvider.overrideWith((ref) => join = _FakeJoin(ref, next)),
      ],
      child: MediaQuery(
        data: MediaQueryData.fromView(tester.view)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: MaterialApp.router(
          theme: theme ?? AppTheme.light,
          routerConfig: router,
        ),
      ),
    ));
    router.pushNamed('room-join');
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'without a name the sheet comes first; closing it goes back '
      '(ROOM-01, ROOM-04)', (tester) async {
    profiles.displayName = null;
    await pump(tester, _phase(JoinPhase.searching));

    expect(find.text('Como você quer aparecer na sala?'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('route:library'), findsOneWidget);
    expect(join.calls, isEmpty);
  });

  testWidgets(
      'searching: "Procurando salas…" and the footer (ROOM-22, '
      'ROOM-38)', (tester) async {
    await pump(tester, _phase(JoinPhase.searching, rooms: const []));

    expect(join.calls.first, 'start:Ana');
    expect(find.text('Procurando salas…'), findsOneWidget);
    expect(find.text('Salas neste Wi‑Fi'), findsOneWidget);
    expect(find.text('Você entra como Cantor.'), findsOneWidget);
  });

  testWidgets('found rooms are tiles with master and song (ROOM-23)',
      (tester) async {
    await pump(tester, _phase(JoinPhase.searching));

    expect(find.byType(RoomTile), findsNWidgets(2));
    expect(find.text('Sala de Marina'), findsOneWidget);
    expect(find.text('Ave Verum Corpus'), findsOneWidget);
    expect(find.text('Sem música escolhida'), findsOneWidget);
    expect(find.text('Procurando salas…'), findsNothing);
  });

  testWidgets(
      'nothing found on Android: banner and "Procurar de novo", no '
      'settings hint (ROOM-24)', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await pump(tester, _phase(JoinPhase.noneFound, rooms: const []));

    expect(find.text('Nenhuma sala neste Wi‑Fi'), findsOneWidget);
    expect(find.textContaining('negou o acesso'), findsNothing);
    expect(find.text('Abrir ajustes'), findsNothing);
    await tapText(tester, 'Procurar de novo');
    expect(join.calls.last, 'searchAgain');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
      'nothing found on iOS adds the hint and "Abrir ajustes" '
      '(ROOM-57)', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await pump(tester, _phase(JoinPhase.noneFound, rooms: const []));

    expect(
        find.textContaining(
            'Se você negou o acesso à rede local, libere nos ajustes.'),
        findsOneWidget);
    await tapText(tester, 'Abrir ajustes');
    expect(join.calls.last, 'settings');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
      'tapping a tile marks it and says whose code to type '
      '(ROOM-28)', (tester) async {
    await pump(tester, _phase(JoinPhase.searching));

    await tester.tap(find.text('Sala de Bruno'));
    await tester.pumpAndSettle();

    expect(join.calls.last, 'select:bruno');
    expect(find.text('Digite o código que aparece na tela de Bruno.'),
        findsOneWidget);
    final tiles = tester.widgetList<RoomTile>(find.byType(RoomTile)).toList();
    expect(tiles.map((t) => t.selected), [false, true]);
    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.focusNode.hasFocus, isTrue);
  });

  testWidgets(
      'typing reaches the state; "Entrar" needs 4 digits '
      '(ROOM-25, ROOM-27)', (tester) async {
    await pump(tester, _phase(JoinPhase.searching));

    await tester.enterText(find.byType(TextField), '482');
    await tester.pump();
    await tapText(tester, 'Entrar');
    expect(join.calls, isNot(contains('submit')));

    await tester.enterText(find.byType(TextField), '4827');
    await tester.pump();
    await tapText(tester, 'Entrar');
    expect(join.calls.last, 'submit');
  });

  testWidgets(
      '"Código não encontrado": error border; "Digitar de novo" '
      'clears and focuses (ROOM-26)', (tester) async {
    await pump(tester, _phase(JoinPhase.codeNotFound, code: '1111'));

    expect(find.text('Código não encontrado'), findsOneWidget);
    expect(tester.widget<CodeInput>(find.byType(CodeInput)).hasError, isTrue);
    await tapText(tester, 'Digitar de novo');

    expect(join.calls.last, 'dismiss');
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.focusNode.hasFocus, isTrue);
    expect(tester.widget<CodeInput>(find.byType(CodeInput)).hasError, isFalse);
  });

  testWidgets(
      'waiting: banner names the master, tile marked, controls off, '
      '"Cancelar pedido" (ROOM-29, ROOM-30, ROOM-55, ROOM-58)', (tester) async {
    await pump(
      tester,
      _phase(JoinPhase.awaiting, target: _marina, code: '4827'),
    );

    expect(find.text('Aguardando Marina aprovar'), findsOneWidget);
    final tiles = tester.widgetList<RoomTile>(find.byType(RoomTile)).toList();
    expect(tiles.map((t) => t.selected), [true, false]);
    expect(tiles.every((t) => t.onTap == null), isTrue);
    expect(tester.widget<CodeInput>(find.byType(CodeInput)).enabled, isFalse);
    await tester.tap(find.text('Sala de Bruno'));
    expect(join.calls, isNot(contains('select:bruno')));

    await tapText(tester, 'Cancelar pedido');
    expect(join.calls.last, 'cancel');
  });

  final outcomes = {
    JoinOutcome.rejected: (
      'Entrada recusada',
      'Escolher outra sala',
      'dismiss'
    ),
    JoinOutcome.roomFull: (
      'Sala cheia (8 de 8)',
      'Escolher outra sala',
      'dismiss'
    ),
    JoinOutcome.protocolMismatch: (
      'Versão do app incompatível',
      'Escolher outra sala',
      'dismiss',
    ),
    JoinOutcome.expired: ('O Mestre não respondeu', 'Tentar de novo', 'retry'),
    JoinOutcome.connectionLost: (
      'Não foi possível falar com a sala',
      'Tentar de novo',
      'retry',
    ),
  };
  for (final MapEntry(key: outcome, value: (title, action, call))
      in outcomes.entries) {
    testWidgets('${outcome.name}: "$title" with "$action" (ROOM-32..36)',
        (tester) async {
      await pump(
        tester,
        _phase(JoinPhase.outcome, outcome: outcome, target: _marina),
      );

      expect(find.text(title), findsOneWidget);
      await tapText(tester, action);
      expect(join.calls.last, call);
    });
  }

  testWidgets('another version says to update both phones (ROOM-34)',
      (tester) async {
    await pump(
      tester,
      _phase(JoinPhase.outcome,
          outcome: JoinOutcome.protocolMismatch, target: _marina),
    );

    expect(find.text('Atualize o Cantaê nos dois aparelhos.'), findsOneWidget);
  });

  testWidgets('a denied permission: banner and "Abrir ajustes" (ROOM-37)',
      (tester) async {
    await pump(tester, _phase(JoinPhase.permissionDenied, rooms: const []));

    expect(find.text('Sem acesso à rede local'), findsOneWidget);
    await tapText(tester, 'Abrir ajustes');
    expect(join.calls.last, 'settings');
  });

  testWidgets('a granted request opens the singer room (ROOM-31)',
      (tester) async {
    await pump(tester, _phase(JoinPhase.awaiting, target: _marina));

    join.set(_phase(JoinPhase.outcome,
        outcome: JoinOutcome.joined, target: _marina));
    await tester.pumpAndSettle();

    expect(find.text('route:room-member'), findsOneWidget);
  });

  testWidgets('state banners are live regions (ROOM-51)', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(
      tester,
      _phase(JoinPhase.outcome, outcome: JoinOutcome.rejected, target: _marina),
    );

    final node = tester.getSemantics(find.ancestor(
      of: find.text('Entrada recusada'),
      matching: find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.liveRegion ?? false)),
    ));
    expect(node.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
    semantics.dispose();
  });

  testWidgets('fits 360 dp at 130 % in both themes (ROOM-51)', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await pump(
        tester,
        _phase(JoinPhase.outcome,
            outcome: JoinOutcome.connectionLost, target: _marina),
        theme: theme,
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
