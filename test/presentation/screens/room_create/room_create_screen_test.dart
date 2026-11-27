import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/session/ids.dart';
import 'package:cantae/presentation/providers/host_room_notifier.dart';
import 'package:cantae/presentation/providers/library_providers.dart';
import 'package:cantae/presentation/providers/room_providers.dart';
import 'package:cantae/presentation/screens/room_create/room_create_screen.dart';
import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/theme/cantae_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../fixtures/room_fakes.dart';

// Failure modes (UI_SPEC §6.7; ROOM-01, 05..21, 51, 52):
// - the room is created before the person has a name, or closing the
//   name sheet leaves an empty screen instead of the Biblioteca;
// - "Gerando código", the permission banner or the failure banner is
//   missing its text or its action;
// - the code, the pill or the song row is missing; "Trocar"/"Escolher
//   música" does not change the song;
// - "Ninguém pediu para entrar ainda" shows with people asking, or not at
//   all; the request buttons act on someone else; a full room still
//   approves;
// - "Começar a conduzir" works before the room is ready, or opens the
//   wrong screen;
// - leaving with people asks nothing, or leaving an empty room asks;
//   system back skips the confirmation;
// - the screen breaks in the dark theme or at 360 dp with 130 % font.
const _ave = Song(id: 'ave', name: 'Ave Verum Corpus', author: 'Mozart');
const _cantate = Song(id: 'cantate', name: 'Cantate Domino', author: '');

class _FakeHost extends HostRoomNotifier {
  _FakeHost(super.ref, this.next);

  final HostRoomState next;
  final calls = <String>[];

  void set(HostRoomState s) => state = s;

  @override
  Future<void> start({required String masterName, String? songId}) async {
    calls.add('start:$masterName:${songId ?? '-'}');
    state = next;
  }

  @override
  Future<void> retry() async => calls.add('retry');
  @override
  Future<void> openSettings() async => calls.add('settings');
  @override
  Future<void> approve(ParticipantId id) async =>
      calls.add('approve:${id.value}');
  @override
  void reject(ParticipantId id) => calls.add('reject:${id.value}');
  @override
  Future<void> chooseSong(Song? song) async =>
      calls.add('song:${song?.id ?? '-'}');
  @override
  Future<void> end() async => calls.add('end');
}

HostRoomState _ready({
  String? songName,
  List<RoomPersonView> pending = const [],
  List<RoomPersonView> members = const [],
  bool isFull = false,
}) =>
    HostRoomState(
      status: HostRoomStatus.ready,
      code: '4827',
      songId: songName == null ? null : 'ave',
      songName: songName,
      people: HostPeople(
        pending: pending,
        members: members,
        isFull: isFull,
        hasPeople: pending.isNotEmpty || members.isNotEmpty,
      ),
    );

const _ana = RoomPersonView(id: ParticipantId('ana'), name: 'Ana');
const _bruno = RoomPersonView(id: ParticipantId('bruno'), name: 'Bruno');

void main() {
  late InMemoryLocalProfiles profiles;
  late _FakeHost host;

  setUp(
      () => profiles = InMemoryLocalProfiles('marina', displayName: 'Marina'));

  Future<void> pump(
    WidgetTester tester,
    HostRoomState next, {
    String? songId,
    ThemeData? theme,
    double textScale = 1,
    bool settle = true,
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
              path: 'room/create',
              name: 'room-create',
              builder: (_, __) => RoomCreateScreen(songId: songId),
            ),
          ],
        ),
        GoRoute(
          path: '/room/host',
          name: 'room-host',
          builder: (_, __) => const Text('route:room-host'),
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        localProfileRepositoryProvider.overrideWithValue(profiles),
        hostRoomProvider.overrideWith((ref) => host = _FakeHost(ref, next)),
        songsProvider.overrideWith((ref) async => [_ave, _cantate]),
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
    router.pushNamed('room-create');
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets(
      'without a name the sheet comes first; closing it goes back '
      'to the Biblioteca (ROOM-01, ROOM-04)', (tester) async {
    profiles.displayName = null;
    await pump(tester, _ready());

    expect(find.text('Como você quer aparecer na sala?'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('route:library'), findsOneWidget);
    expect(host.calls.where((c) => c.startsWith('start')), isEmpty);
  });

  testWidgets(
      'starts the room with the saved name and the song from the '
      'Detalhe (ROOM-07)', (tester) async {
    await pump(tester, _ready(songName: 'Ave Verum Corpus'), songId: 'ave');

    expect(host.calls.first, 'start:Marina:ave');
    expect(find.text('Ave Verum Corpus'), findsOneWidget);
    expect(find.text('Trocar'), findsOneWidget);
  });

  testWidgets('"Gerando código" while the room starts (ROOM-05)',
      (tester) async {
    await pump(tester, const HostRoomState(), settle: false);

    expect(find.text('Gerando código'), findsOneWidget);
    expect(find.text('Visível neste Wi‑Fi'), findsNothing);
    await tester.tap(find.text('Começar a conduzir'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('route:room-host'), findsNothing);
  });

  testWidgets(
      'ready: code, pill and "Ninguém pediu para entrar ainda" '
      '(ROOM-05, ROOM-10)', (tester) async {
    await pump(tester, _ready());

    expect(find.text('4827'), findsOneWidget);
    expect(find.text('Visível neste Wi‑Fi'), findsOneWidget);
    expect(find.text('Ninguém pediu para entrar ainda'), findsOneWidget);
    expect(find.text('Na sala · 0 de 8'), findsOneWidget);
    expect(find.text('Você'), findsOneWidget);
  });

  testWidgets(
      'from the Biblioteca: "Escolher música" picks a song '
      '(ROOM-08, ROOM-09)', (tester) async {
    await pump(tester, _ready());
    expect(find.text('Nenhuma música escolhida'), findsOneWidget);

    await tester.tap(find.text('Escolher música'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cantate Domino'));
    await tester.pumpAndSettle();

    expect(host.calls.last, 'song:cantate');
  });

  testWidgets(
      'requests list names; each button acts on its person '
      '(ROOM-11, ROOM-53)', (tester) async {
    await pump(tester, _ready(pending: [_ana, _bruno]));

    expect(find.text('Pedindo para entrar · 2'), findsOneWidget);
    expect(find.text('Ninguém pediu para entrar ainda'), findsNothing);
    await tester.tap(find.text('Aprovar').last);
    await tester.tap(find.text('Recusar').first);

    expect(host.calls.sublist(1), ['approve:bruno', 'reject:ana']);
  });

  testWidgets('people in the room are listed with the count (ROOM-12)',
      (tester) async {
    await pump(tester, _ready(members: [_ana]));

    expect(find.text('Na sala · 1 de 8'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text(' · Cantor'), findsOneWidget);
  });

  testWidgets('a full room turns "Aprovar" off and says why (ROOM-14)',
      (tester) async {
    await pump(tester, _ready(pending: [_bruno], isFull: true));

    await tester.tap(find.text('Aprovar'));
    expect(host.calls.where((c) => c.startsWith('approve')), isEmpty);
    expect(find.text('Sala cheia: 8 de 8.'), findsOneWidget);
  });

  testWidgets('the permission banner opens the settings (ROOM-20)',
      (tester) async {
    await pump(
        tester, const HostRoomState(status: HostRoomStatus.permissionDenied));

    expect(find.text('Sem acesso à rede local'), findsOneWidget);
    await tester.tap(find.text('Abrir ajustes'));

    expect(host.calls.last, 'settings');
  });

  testWidgets('the failure banner tries again (ROOM-21)', (tester) async {
    await pump(tester, const HostRoomState(status: HostRoomStatus.failed));

    expect(find.text('Não foi possível criar a sala.'), findsOneWidget);
    await tester.tap(find.text('Tentar de novo'));

    expect(host.calls.last, 'retry');
  });

  testWidgets('"Começar a conduzir" opens the master room (ROOM-17)',
      (tester) async {
    await pump(tester, _ready());

    await tester.tap(find.text('Começar a conduzir'));
    await tester.pumpAndSettle();

    expect(find.text('route:room-host'), findsOneWidget);
    expect(host.calls, isNot(contains('end')));
  });

  testWidgets('"Cancelar" with nobody ends the room at once (ROOM-19)',
      (tester) async {
    await pump(tester, _ready());

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Encerrar sala?'), findsNothing);
    expect(host.calls.last, 'end');
    expect(find.text('route:library'), findsOneWidget);
  });

  testWidgets(
      '"Cancelar" with people asks first; "Continuar na sala" stays '
      '(ROOM-18)', (tester) async {
    await pump(tester, _ready(pending: [_ana]));

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Encerrar sala?'), findsOneWidget);
    await tester.tap(find.text('Continuar na sala'));
    await tester.pumpAndSettle();

    expect(host.calls, isNot(contains('end')));
    expect(find.text('4827'), findsOneWidget);
  });

  testWidgets('confirming "Encerrar sala" ends it (ROOM-18)', (tester) async {
    await pump(tester, _ready(members: [_ana]));

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Encerrar sala'));
    await tester.pumpAndSettle();

    expect(host.calls.last, 'end');
    expect(find.text('route:library'), findsOneWidget);
  });

  testWidgets('system back asks like "Cancelar" (ROOM-18)', (tester) async {
    await pump(tester, _ready(pending: [_ana]));

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Encerrar sala?'), findsOneWidget);
  });

  testWidgets(
      'fits 360 dp at 130 % in both themes with a full room '
      '(ROOM-51)', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await pump(
        tester,
        _ready(
            songName: 'Ave Verum Corpus', pending: [_ana], members: [_bruno]),
        theme: theme,
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester
            .getSize(find.ancestor(
                of: find.text('Cancelar'), matching: find.byType(InkWell)))
            .height,
        greaterThanOrEqualTo(CantaeSpacing.minTouchTarget),
      );
    }
  });
}
