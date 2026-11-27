import 'package:cantae/domain/session/ids.dart';
import 'package:cantae/presentation/providers/host_room_notifier.dart';
import 'package:cantae/presentation/screens/room_host/room_host_screen.dart';
import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// Failure modes (ROOM-39..41, ROOM-45): the title misses the code; the
// master or the singers are missing or have the wrong role; pending
// requests cannot be answered here; "Encerrar sala" ends without asking,
// or asking and confirming leaves the room open; system back with nobody
// asks anyway, or with people skips the question; opening the screen with
// no room shows an empty page instead of the Biblioteca; the screen breaks
// in the dark theme or at 360 dp with 130 % font.
class _FakeHost extends HostRoomNotifier {
  _FakeHost(super.ref, this.next, {this.hasRoom = true});

  final HostRoomState next;
  final bool hasRoom;
  final calls = <String>[];

  @override
  bool resume() {
    calls.add('resume');
    if (hasRoom) state = next;
    return hasRoom;
  }

  @override
  Future<void> start({required String masterName, String? songId}) async =>
      calls.add('start');
  @override
  Future<void> approve(ParticipantId id) async =>
      calls.add('approve:${id.value}');
  @override
  void reject(ParticipantId id) => calls.add('reject:${id.value}');
  @override
  Future<void> end() async => calls.add('end');
}

const _ana = RoomPersonView(id: ParticipantId('ana'), name: 'Ana');
const _bruno = RoomPersonView(id: ParticipantId('bruno'), name: 'Bruno');

HostRoomState _room({
  List<RoomPersonView> pending = const [],
  List<RoomPersonView> members = const [],
}) =>
    HostRoomState(
      status: HostRoomStatus.ready,
      code: '4827',
      songName: 'Ave Verum Corpus',
      people: HostPeople(
        pending: pending,
        members: members,
        hasPeople: pending.isNotEmpty || members.isNotEmpty,
      ),
    );

void main() {
  late _FakeHost host;

  Future<void> pump(
    WidgetTester tester,
    HostRoomState next, {
    bool hasRoom = true,
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
              path: 'room/host',
              name: 'room-host',
              builder: (_, __) => const RoomHostScreen(),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        hostRoomProvider.overrideWith(
            (ref) => host = _FakeHost(ref, next, hasRoom: hasRoom)),
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
    router.pushNamed('room-host');
    await tester.pumpAndSettle();
  }

  testWidgets(
      'shows "Sala <código>", the song, the master and the singers '
      '(ROOM-39)', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, _room(members: [_ana, _bruno]));

    expect(host.calls, ['resume']);
    expect(find.text('Sala 4827'), findsOneWidget);
    expect(find.text('Ave Verum Corpus'), findsOneWidget);
    expect(find.bySemanticsLabel('Você, Mestre'), findsOneWidget);
    expect(find.bySemanticsLabel('Ana, Cantor'), findsOneWidget);
    expect(find.bySemanticsLabel('Bruno, Cantor'), findsOneWidget);
    expect(find.text('Na sala · 2 de 8'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('pending requests can be answered here (ROOM-40)',
      (tester) async {
    await pump(tester, _room(pending: [_ana]));

    expect(find.text('Pedindo para entrar · 1'), findsOneWidget);
    await tester.tap(find.text('Aprovar'));
    await tester.tap(find.text('Recusar'));

    expect(host.calls.sublist(1), ['approve:ana', 'reject:ana']);
  });

  testWidgets(
      '"Encerrar sala" asks, then ends and goes to the Biblioteca '
      '(ROOM-41)', (tester) async {
    await pump(tester, _room());

    await tester.tap(find.text('Encerrar sala'));
    await tester.pumpAndSettle();
    expect(find.text('Encerrar sala?'), findsOneWidget);
    expect(host.calls, isNot(contains('end')));
    await tester.tap(find.text('Encerrar sala').last);
    await tester.pumpAndSettle();

    expect(host.calls.last, 'end');
    expect(find.text('route:library'), findsOneWidget);
  });

  testWidgets('"Continuar na sala" keeps the room (ROOM-41)', (tester) async {
    await pump(tester, _room(members: [_ana]));

    await tester.tap(find.text('Encerrar sala'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar na sala'));
    await tester.pumpAndSettle();

    expect(host.calls, isNot(contains('end')));
    expect(find.text('Sala 4827'), findsOneWidget);
  });

  testWidgets('system back with nobody ends at once (ROOM-45, ROOM-19)',
      (tester) async {
    await pump(tester, _room());

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Encerrar sala?'), findsNothing);
    expect(host.calls.last, 'end');
    expect(find.text('route:library'), findsOneWidget);
  });

  testWidgets('system back with people asks first (ROOM-45, ROOM-18)',
      (tester) async {
    await pump(tester, _room(members: [_ana]));

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Encerrar sala?'), findsOneWidget);
    expect(host.calls, isNot(contains('end')));
  });

  testWidgets('with no room it goes to the Biblioteca and creates none',
      (tester) async {
    await pump(tester, _room(), hasRoom: false);

    expect(find.text('route:library'), findsOneWidget);
    expect(host.calls, isNot(contains('start')));
  });

  testWidgets('fits 360 dp at 130 % in both themes', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await pump(tester, _room(pending: [_bruno], members: [_ana]),
          theme: theme, textScale: 1.3);
      expect(tester.takeException(), isNull);
    }
  });
}
