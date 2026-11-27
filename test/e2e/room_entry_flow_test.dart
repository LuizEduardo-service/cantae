// End-to-end flow for room-entry (ROOM-01, 12, 13, 17, 26, 31, 32, 41, 44,
// 46).
//
// Real pieces: two RoomSessionControllers talking over loopback TCP with
// the real handshake; the singer's app (router, screens, name sheet,
// notifiers, drift profile in memory); the master's HostRoomNotifier, the
// same one Criar sala uses, in its own ProviderContainer. Only mDNS is
// replaced by an in-memory Wi‑Fi (RoomBus), since it needs real devices.
//
// Artifact: the test prints each step with what each side saw.
import 'package:cantae/data/repositories/drift_local_profile_repository.dart';
import 'package:cantae/data/session/room_session_controller.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/core/unit.dart';
import 'package:cantae/domain/session/handshake_service.dart';
import 'package:cantae/domain/session/ids.dart';
import 'package:cantae/domain/session/system_settings.dart';
import 'package:cantae/infrastructure/database/app_database.dart';
import 'package:cantae/infrastructure/network/tcp_session_transport.dart';
import 'package:cantae/presentation/providers/host_room_notifier.dart';
import 'package:cantae/presentation/providers/room_providers.dart';
import 'package:cantae/presentation/providers/song_repository_provider.dart';
import 'package:cantae/presentation/routing/app_router.dart';
import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/room_fakes.dart';

class _NoSettings implements SystemSettings {
  @override
  Future<void> openAppSettings() async {}
}

final _log = <String>[];
void _step(String line) => _log.add(line);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets(
      'Ana names herself, mistypes the code, asks Marina\'s room, waits, gets '
      'in; Bruno is refused; Marina ends the room', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();

    final bus = RoomBus();
    addTearDown(bus.close);

    // Marina's phone: no screen, the same notifier Criar sala uses.
    final master = ProviderContainer(overrides: [
      roomDiscoveryProvider.overrideWithValue(InMemoryRoomDiscovery(bus)),
      localProfileRepositoryProvider.overrideWithValue(
        InMemoryLocalProfiles('marina-phone', displayName: 'Marina'),
      ),
    ]);
    addTearDown(master.dispose);
    master.listen(hostRoomProvider, (_, __) {});
    HostRoomState host() => master.read(hostRoomProvider);

    // Ana's phone: the real app.
    final anaDb = AppDatabase(NativeDatabase.memory());
    addTearDown(anaDb.close);
    final ana = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(anaDb),
      roomDiscoveryProvider.overrideWithValue(InMemoryRoomDiscovery(bus)),
      localProfileRepositoryProvider.overrideWithValue(
        DriftLocalProfileRepository(anaDb, newId: () => 'ana-phone'),
      ),
      systemSettingsProvider.overrideWithValue(_NoSettings()),
    ]);
    addTearDown(ana.dispose);

    await tester.runAsync(() =>
        master.read(hostRoomProvider.notifier).start(masterName: 'Marina'));
    final code = host().code!;
    _step('Marina created room ${host().code} (status ${host().status.name})');

    await tester.pumpWidget(UncontrolledProviderScope(
      container: ana,
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: ana.read(routerProvider),
      ),
    ));
    await _settle(tester, () => find.text('Entrar em sala'));

    // Biblioteca → Entrar em sala → name sheet (ROOM-01).
    await _tap(tester, find.text('Entrar em sala').last);
    await _settle(tester, () => find.text('Como você quer aparecer na sala?'));
    await tester.enterText(find.byType(TextField), 'Ana');
    await tester.pump();
    await _tap(tester, find.text('Salvar nome'));
    await _settle(tester, () => find.text('Sala de Marina'));
    _step('Ana saved her name and sees "Sala de Marina" (no code on the '
        'tile: ${find.text(code).evaluate().isEmpty})');
    expect(find.text(code), findsNothing, reason: 'NET-01');

    // A wrong code on the chosen room (ROOM-26).
    await _tap(tester, find.text('Sala de Marina'));
    final wrong = code == '0000' ? '1111' : '0000';
    await tester.enterText(find.byType(TextField), wrong);
    await tester.pump();
    await _tap(tester, find.text('Entrar'));
    await _settle(tester, () => find.text('Código não encontrado'));
    _step('Ana typed $wrong → "Código não encontrado"');
    await _tap(tester, find.text('Digitar de novo'));

    // The right code: the request waits for Marina (ROOM-29, ROOM-46).
    await tester.enterText(find.byType(TextField), code);
    await tester.pump();
    await _tap(tester, find.text('Entrar'));
    await _settle(tester, () => find.text('Aguardando Marina aprovar'));
    await _until(tester, () => host().people.pending.isNotEmpty);
    expect(host().people.pending.single.name, 'Ana');
    expect(host().people.members, isEmpty,
        reason: 'the code alone never admits anyone (ROOM-46)');
    _step('Ana typed the code → waiting; Marina sees pending '
        '${host().people.pending.map((p) => p.name)} and members '
        '${host().people.members.map((p) => p.name)}');

    // Marina approves → Ana reaches her room (ROOM-12, ROOM-31).
    await tester.runAsync(() => master
        .read(hostRoomProvider.notifier)
        .approve(host().people.pending.single.id));
    await _settle(tester, () => find.text('Você está na sala de Marina'));
    await _until(tester, () => host().people.members.isNotEmpty);
    expect(host().people.members.single.name, 'Ana');
    _step('Marina approved → Ana is in; Marina sees members '
        '${host().people.members.map((p) => p.name)}');

    // Bruno asks too and Marina refuses (ROOM-13, ROOM-32).
    final bruno = RoomSessionController(
      transport: TcpSessionTransport(),
      discovery: InMemoryRoomDiscovery(bus),
      handshakeService: HandshakeService(),
      selfDeviceId: const DeviceId('bruno-phone'),
    );
    addTearDown(bruno.dispose);
    final brunoResult = await tester.runAsync(() async {
      final room = await bruno.discoverRooms().firstWhere((r) => r.available);
      final join = bruno.requestJoin(room.id, code, displayName: 'Bruno');
      await _untilAsync(() => host().people.pending.isNotEmpty);
      master
          .read(hostRoomProvider.notifier)
          .reject(host().people.pending.single.id);
      return join.timeout(const Duration(seconds: 5));
    });
    final brunoCode = (brunoResult as Result<Unit, Failure>)
        .when(success: (_) => 'joined', failure: (f) => f.code);
    expect(brunoCode, 'session.rejected');
    await _until(tester, () => host().people.pending.isEmpty);
    _step('Bruno asked and Marina refused → Bruno got $brunoCode; Marina '
        'still has members ${host().people.members.map((p) => p.name)}');

    // Marina ends the room → Ana is back at the Biblioteca (ROOM-41/44).
    await tester.runAsync(() => master.read(hostRoomProvider.notifier).end());
    await _settle(
        tester, () => find.text('A sala foi encerrada ou a conexão caiu.'));
    expect(find.text('Você está na sala de Marina'), findsNothing);
    _step('Marina ended the room → Ana sees the toast and the Biblioteca');

    // ignore: avoid_print
    print(['room-entry e2e artifact', ..._log.map((l) => '  $l')].join('\n'));

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
  });
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

/// Lets real sockets and isolates run, pumping frames until [finder] shows
/// something.
Future<void> _settle(WidgetTester tester, Finder Function() finder) async {
  for (var i = 0; i < 300 && finder().evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(finder(), findsWidgets);
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _until(WidgetTester tester, bool Function() test) async {
  for (var i = 0; i < 300 && !test(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(test(), isTrue);
}

Future<void> _untilAsync(bool Function() test) async {
  for (var i = 0; i < 300 && !test(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
