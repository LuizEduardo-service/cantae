import 'dart:typed_data';

import 'package:cantae/data/session/room_session_controller.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/core/unit.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/repositories/song_repository.dart';
import 'package:cantae/domain/session/handshake_service.dart';
import 'package:cantae/domain/session/ids.dart';
import 'package:cantae/domain/session/participant_session.dart';
import 'package:cantae/domain/session/room.dart';
import 'package:cantae/domain/session/room_discovery.dart';
import 'package:cantae/domain/session/room_session_snapshot.dart';
import 'package:cantae/domain/session/system_settings.dart';
import 'package:cantae/infrastructure/network/tcp_session_transport.dart';
import 'package:cantae/presentation/providers/active_room_notifier.dart';
import 'package:cantae/presentation/providers/host_room_notifier.dart';
import 'package:cantae/presentation/providers/room_providers.dart';
import 'package:cantae/presentation/providers/song_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/room_fakes.dart';

// Failure modes (ROOM-05, 07..21, 39, 40, 53, 54):
// - the screen shows a code before the room is announced, or none after;
// - the song from the Detalhe is not preselected or not announced;
// - changing or clearing the song is not announced;
// - a request is missing, has no name, or two requests collapse into one;
// - an approved person shows up "in the room" before the secure connection
//   is ready, or never shows up;
// - a refused, expired or disconnected person stays listed;
// - the room looks open with 8 people, so a 9th approval is tried;
// - a denied permission looks like a generic failure, and "Tentar de
//   novo" does not try again;
// - the master's temporary room opens a second room with a new code.
const _ave = Song(id: 'ave', name: 'Ave Verum Corpus', author: 'Mozart');
const _cantate = Song(id: 'cantate', name: 'Cantate Domino', author: '');

class _Songs implements SongRepository {
  @override
  Future<Result<Song, Failure>> getById(String id) async => id == _ave.id
      ? const Result.success(_ave)
      : Result.failure(NotFoundFailure(code: 'song_not_found'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Settings implements SystemSettings {
  var opened = 0;

  @override
  Future<void> openAppSettings() async => opened++;
}

void main() {
  late RoomBus bus;
  late InMemoryRoomDiscovery masterDiscovery;
  late _Settings settings;
  late ProviderContainer container;
  late DateTime fakeNow;
  final joiners = <RoomSessionController>[];

  RoomSessionController controllerFor(
    DeviceId self,
    RoomDiscovery discovery,
  ) =>
      RoomSessionController(
        transport: TcpSessionTransport(),
        discovery: discovery,
        handshakeService: HandshakeService(),
        selfDeviceId: self,
        now: () => fakeNow,
        tickInterval: const Duration(milliseconds: 20),
      );

  setUp(() {
    fakeNow = DateTime(2026, 11, 26, 19);
    bus = RoomBus();
    masterDiscovery = InMemoryRoomDiscovery(bus);
    settings = _Settings();
    container = ProviderContainer(overrides: [
      activeRoomProvider.overrideWith((ref) => ActiveRoomNotifier(
            newController: (self) => controllerFor(self, masterDiscovery),
            profiles: InMemoryLocalProfiles('marina'),
          )),
      songRepositoryProvider.overrideWithValue(_Songs()),
      systemSettingsProvider.overrideWithValue(settings),
    ]);
  });

  tearDown(() async {
    for (final j in joiners) {
      j.dispose();
    }
    joiners.clear();
    container.dispose();
    await bus.close();
  });

  HostRoomNotifier notifier() {
    container.listen(hostRoomProvider, (_, __) {});
    return container.read(hostRoomProvider.notifier);
  }

  HostRoomState state() => container.read(hostRoomProvider);

  /// A singer device that found the room and sent a request as [name].
  Future<(RoomSessionController, Future<Result<Unit, Failure>>)> ask(
    String name,
  ) async {
    final joiner = controllerFor(DeviceId(name), InMemoryRoomDiscovery(bus));
    joiners.add(joiner);
    final room = await joiner
        .discoverRooms()
        .firstWhere((r) => r.available)
        .timeout(const Duration(seconds: 5));
    return (
      joiner,
      joiner.requestJoin(room.id, state().code!, displayName: name)
    );
  }

  Future<void> until(bool Function(HostRoomState s) test) async {
    for (var i = 0; i < 250 && !test(state()); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(test(state()), isTrue, reason: 'state never matched');
  }

  test(
      'shows "generating" until the room is announced, then its code '
      '(ROOM-05)', () async {
    final starting = notifier().start(masterName: 'Marina');
    expect(state().status, HostRoomStatus.generating);
    expect(state().code, isNull);

    await starting;

    expect(state().status, HostRoomStatus.ready);
    expect(state().code, matches(RegExp(r'^\d{4}$')));
    expect(state().people.hasPeople, isFalse);
  });

  test('a song from the Detalhe comes preselected and announced (ROOM-07)',
      () async {
    await notifier().start(masterName: 'Marina', songId: 'ave');

    expect(state().songId, 'ave');
    expect(state().songName, 'Ave Verum Corpus');
    expect(masterDiscovery.announcements.single.songName, 'Ave Verum Corpus');
  });

  test('from the Biblioteca there is no song and the room works (ROOM-08)',
      () async {
    await notifier().start(masterName: 'Marina');

    expect(state().songName, isNull);
    expect(state().status, HostRoomStatus.ready);
    expect(masterDiscovery.announcements.single.songName, isNull);
  });

  test('choosing and clearing the song is announced (ROOM-09)', () async {
    final n = notifier();
    await n.start(masterName: 'Marina', songId: 'ave');

    await n.chooseSong(_cantate);
    expect(state().songName, 'Cantate Domino');
    expect(masterDiscovery.announcements.last.songName, 'Cantate Domino');

    await n.chooseSong(null);
    expect(state().songName, isNull);
    expect(state().songId, isNull);
    expect(masterDiscovery.announcements.last.songName, isNull);
  });

  test('two requests are listed with their names (ROOM-11, ROOM-53)', () async {
    await notifier().start(masterName: 'Marina');

    await ask('Ana');
    await ask('Bruno');

    await until((s) => s.people.pending.length == 2);
    expect(state().people.pending.map((p) => p.name), ['Ana', 'Bruno']);
    expect(state().people.hasPeople, isTrue);
  });

  test('an approved person moves to "Na sala" once connected (ROOM-12)',
      () async {
    final n = notifier();
    await n.start(masterName: 'Marina');
    final (_, join) = await ask('Ana');
    await until((s) => s.people.pending.isNotEmpty);

    await n.approve(state().people.pending.single.id);

    expect((await join.timeout(const Duration(seconds: 5))).isSuccess, isTrue);
    await until((s) => s.people.members.length == 1);
    expect(state().people.members.single.name, 'Ana');
    expect(state().people.pending, isEmpty);
  });

  test('"Recusar" drops the request (ROOM-13)', () async {
    final n = notifier();
    await n.start(masterName: 'Marina');
    final (_, join) = await ask('Ana');
    await until((s) => s.people.pending.isNotEmpty);

    n.reject(state().people.pending.single.id);

    await until((s) => s.people.pending.isEmpty);
    final code = (await join.timeout(const Duration(seconds: 5)))
        .when(success: (_) => null, failure: (f) => f.code);
    expect(code, 'session.rejected');
  });

  test('an expired request disappears (ROOM-15)', () async {
    await notifier().start(masterName: 'Marina');
    await ask('Ana');
    await until((s) => s.people.pending.isNotEmpty);

    fakeNow = fakeNow.add(const Duration(seconds: 61));

    await until((s) => s.people.pending.isEmpty);
  });

  test('a person who leaves is dropped from "Na sala" (ROOM-16)', () async {
    final n = notifier();
    await n.start(masterName: 'Marina');
    final (joiner, join) = await ask('Ana');
    await until((s) => s.people.pending.isNotEmpty);
    await n.approve(state().people.pending.single.id);
    await join;
    await until((s) => s.people.members.isNotEmpty);

    await joiner.leaveRoom();

    await until((s) => s.people.members.isEmpty);
    expect(state().people.hasPeople, isFalse);
  });

  test(
      'a denied permission has its own state and opens the settings '
      '(ROOM-20)', () async {
    masterDiscovery.advertiseResult =
        Result.failure(NetworkFailure(code: 'discovery.permission-denied'));
    final n = notifier();

    await n.start(masterName: 'Marina');
    await n.openSettings();

    expect(state().status, HostRoomStatus.permissionDenied);
    expect(state().code, isNull);
    expect(settings.opened, 1);
  });

  test(
      'another failure has its own state and "Tentar de novo" retries '
      '(ROOM-21)', () async {
    masterDiscovery.advertiseResult =
        Result.failure(NetworkFailure(code: 'discovery.failed'));
    final n = notifier();
    await n.start(masterName: 'Marina');
    expect(state().status, HostRoomStatus.failed);

    masterDiscovery.advertiseResult = const Result.success(Unit());
    await n.retry();

    expect(state().status, HostRoomStatus.ready);
    expect(state().code, isNotNull);
  });

  test('the temporary room shows the same room, no new code (ROOM-17)',
      () async {
    await notifier().start(masterName: 'Marina');
    final code = state().code;

    // The Criar sala screen goes away; the master's room screen opens.
    container.invalidate(hostRoomProvider);
    await notifier().start(masterName: 'Marina');

    expect(state().code, code);
    expect(masterDiscovery.announcements, hasLength(1));
  });

  test('resume shows the hosted room and never creates one (ROOM-39)',
      () async {
    expect(notifier().resume(), isFalse);
    expect(container.read(activeRoomProvider), isNull);
    expect(masterDiscovery.announcements, isEmpty);

    await notifier().start(masterName: 'Marina');
    final code = state().code;
    container.invalidate(hostRoomProvider);

    expect(notifier().resume(), isTrue);
    expect(state().code, code);
    expect(state().status, HostRoomStatus.ready);
    expect(masterDiscovery.announcements, hasLength(1));
  });

  test('"Encerrar sala" ends the room (ROOM-41)', () async {
    final n = notifier();
    await n.start(masterName: 'Marina');

    await n.end();

    expect(container.read(activeRoomProvider), isNull);
    expect(masterDiscovery.stops, 1);
  });

  group('hostPeopleOf', () {
    ParticipantSession person(int i, ParticipantState state) =>
        ParticipantSession(
          id: ParticipantId('p$i'),
          role: ParticipantRole.visitor,
          state: state,
          sessionKey:
              state == ParticipantState.connected ? Uint8List(32) : null,
          lastAcceptedSequence: -1,
          lastActivityAt: DateTime(2026),
          pendingSince: null,
          displayName: 'Pessoa $i',
        );

    HostPeople of(List<ParticipantSession> people) =>
        hostPeopleOf(RoomSessionSnapshot(
          room: const Room(
            id: RoomId('r'),
            code: '4827',
            masterId: DeviceId('m'),
            state: RoomLifecycle.advertising,
          ),
          participants: people,
        ));

    test('8 people in the room fill it (ROOM-14)', () {
      final people = of([
        for (var i = 0; i < 8; i++) person(i, ParticipantState.connected),
        person(9, ParticipantState.pendingApproval),
      ]);

      expect(people.isFull, isTrue);
      expect(people.members, hasLength(8));
      expect(people.pending.single.name, 'Pessoa 9');
    });

    test(
        '7 in and 1 connecting is full, and the connecting one is not '
        'listed (ROOM-12, ROOM-54)', () {
      final people = of([
        for (var i = 0; i < 7; i++) person(i, ParticipantState.connected),
        person(7, ParticipantState.approved),
      ]);

      expect(people.isFull, isTrue);
      expect(people.members, hasLength(7));
      expect(people.pending, isEmpty);
      expect(people.hasPeople, isTrue);
    });

    test('7 in is not full', () {
      expect(
        of([for (var i = 0; i < 7; i++) person(i, ParticipantState.connected)])
            .isFull,
        isFalse,
      );
    });

    test('refused, expired and gone people are not listed', () {
      final people = of([
        person(0, ParticipantState.rejected),
        person(1, ParticipantState.expired),
        person(2, ParticipantState.disconnected),
      ]);

      expect(people.pending, isEmpty);
      expect(people.members, isEmpty);
      expect(people.hasPeople, isFalse);
    });
  });
}
