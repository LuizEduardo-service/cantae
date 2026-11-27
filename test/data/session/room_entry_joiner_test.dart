import 'dart:async';
import 'dart:io';

import 'package:cantae/data/session/room_session_controller.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/core/unit.dart';
import 'package:cantae/domain/session/handshake_service.dart';
import 'package:cantae/domain/session/ids.dart';
import 'package:cantae/domain/session/participant_session.dart';
import 'package:cantae/domain/session/room_discovery.dart';
import 'package:cantae/domain/session/room_session_snapshot.dart';
import 'package:cantae/infrastructure/network/tcp_session_transport.dart';
import 'package:flutter_test/flutter_test.dart';

// Failure modes, singer side (ROOM-25, 30, 35, 36, 43, 44, 58):
// - after a room answers "wrong code", the next request on another room
//   fails or reuses the dead connection;
// - the room closes the connection before answering and the request
//   waits forever ("Aguardando" with no way out);
// - the room cannot be reached and the request throws instead of failing;
// - the room never answers (app killed without closing) and the request
//   waits forever;
// - "Cancelar pedido" leaves the request pending on the master's screen;
// - "Sair da sala" leaves the singer listed in the room;
// - the master ends the room and the singer is not told, or is told twice;
// - leaving on purpose is reported as a lost room.
class _BusDiscovery implements RoomDiscovery {
  _BusDiscovery(this.bus);

  final StreamController<DiscoveredRoom> bus;

  @override
  Future<Result<Unit, NetworkFailure>> advertise(
    RoomId id,
    int port,
    RoomAnnouncement announcement,
  ) async {
    bus.add(DiscoveredRoom(
      id: id,
      host: '127.0.0.1',
      port: port,
      masterName: announcement.masterName,
    ));
    return const Result.success(Unit());
  }

  @override
  Stream<DiscoveredRoom> discover() => bus.stream;

  @override
  Future<void> stopAdvertising() async {}
}

void main() {
  late StreamController<DiscoveredRoom> bus;
  final toDispose = <RoomSessionController>[];
  final servers = <TcpSessionTransport>[];

  RoomSessionController controller(
    String id, {
    Duration joinAnswerTimeout = const Duration(seconds: 75),
  }) {
    final c = RoomSessionController(
      transport: TcpSessionTransport(),
      discovery: _BusDiscovery(bus),
      handshakeService: HandshakeService(),
      selfDeviceId: DeviceId(id),
      joinAnswerTimeout: joinAnswerTimeout,
    );
    toDispose.add(c);
    return c;
  }

  setUp(() => bus = StreamController<DiscoveredRoom>.broadcast());

  tearDown(() async {
    for (final c in toDispose) {
      c.dispose();
    }
    toDispose.clear();
    servers.clear();
    await bus.close();
  });

  String? failureCode(Result<Object?, Failure> r) =>
      r.when(success: (_) => null, failure: (f) => f.code);

  /// Creates [master]'s room and lets [joiner] find it.
  Future<DiscoveredRoom> open(
    RoomSessionController master,
    RoomSessionController joiner,
  ) async {
    final found = joiner.discoverRooms().first;
    await master.createRoom(masterName: 'Marina');
    return found.timeout(const Duration(seconds: 5));
  }

  Future<RoomSessionSnapshot> snapshotWhere(
    RoomSessionController master,
    bool Function(ParticipantSession p) test,
  ) =>
      master.snapshots
          .firstWhere((s) => s.participants.any(test))
          .timeout(const Duration(seconds: 5));

  /// A fake room on a bare TCP server; [onConnection] decides what it does.
  Future<DiscoveredRoom> fakeRoom(
    RoomSessionController joiner,
    void Function(TcpSessionTransport server, ParticipantId c) onConnection,
  ) async {
    final server = TcpSessionTransport();
    servers.add(server);
    await server.listen(0);
    server.incomingConnections.listen((c) => onConnection(server, c));
    final found = joiner.discoverRooms().first;
    bus.add(DiscoveredRoom(
      id: const RoomId('fake'),
      host: '127.0.0.1',
      port: server.boundPort,
      masterName: 'Bruno',
    ));
    return found.timeout(const Duration(seconds: 5));
  }

  Future<Result<Unit, Failure>> joined(
    RoomSessionController master,
    RoomSessionController joiner,
    DiscoveredRoom room,
  ) async {
    final join =
        joiner.requestJoin(room.id, master.roomCode!, displayName: 'Ana');
    final pending = await snapshotWhere(
        master, (p) => p.state == ParticipantState.pendingApproval);
    await master.approve(pending.participants.single.id);
    return join.timeout(const Duration(seconds: 5));
  }

  test(
      'after "wrong code" the same controller can ask another room '
      '(ROOM-25, ROOM-58)', () async {
    final wrongRoom = controller('bruno');
    final rightRoom = controller('marina');
    final joiner = controller('ana');
    final rooms = joiner.discoverRooms().take(2).toList();
    await wrongRoom.createRoom(masterName: 'Bruno');
    await rightRoom.createRoom(masterName: 'Marina');
    final [first, second] = await rooms.timeout(const Duration(seconds: 5));

    final refused = await joiner
        .requestJoin(first.id, rightRoom.roomCode!, displayName: 'Ana')
        .timeout(const Duration(seconds: 5));
    expect(failureCode(refused), 'session.invalid-code');

    final join =
        joiner.requestJoin(second.id, rightRoom.roomCode!, displayName: 'Ana');
    final pending = await snapshotWhere(
        rightRoom, (p) => p.state == ParticipantState.pendingApproval);
    expect(pending.participants.single.displayName, 'Ana');
    await rightRoom.approve(pending.participants.single.id);
    expect((await join.timeout(const Duration(seconds: 5))).isSuccess, isTrue);
  });

  test(
      'a room that closes before answering ends the request as a lost '
      'connection (ROOM-36)', () async {
    final joiner = controller('ana');
    final room = await fakeRoom(joiner, (server, c) => server.close(c));

    final result = await joiner
        .requestJoin(room.id, '1234', displayName: 'Ana')
        .timeout(const Duration(seconds: 5));

    expect(failureCode(result), 'session.connection-lost');
  });

  test('a room that cannot be reached fails the request (ROOM-36)', () async {
    final joiner = controller('ana');
    final found = joiner.discoverRooms().first;
    final closedServer = await ServerSocket.bind('127.0.0.1', 0);
    final port = closedServer.port;
    await closedServer.close();
    bus.add(DiscoveredRoom(
        id: const RoomId('gone'), host: '127.0.0.1', port: port));
    final room = await found;

    final result = await joiner
        .requestJoin(room.id, '1234', displayName: 'Ana')
        .timeout(const Duration(seconds: 10));

    expect(failureCode(result), 'session.connect-failed');
  });

  test('a room that never answers ends the request as expired (ROOM-35)',
      () async {
    final joiner =
        controller('ana', joinAnswerTimeout: const Duration(milliseconds: 200));
    final room = await fakeRoom(joiner, (_, __) {});

    final result = await joiner
        .requestJoin(room.id, '1234', displayName: 'Ana')
        .timeout(const Duration(seconds: 5));

    expect(failureCode(result), 'session.request-expired');
  });

  test(
      '"Cancelar pedido" ends the request and the master loses it '
      '(ROOM-30)', () async {
    final master = controller('marina');
    final joiner = controller('ana');
    final room = await open(master, joiner);
    final join =
        joiner.requestJoin(room.id, master.roomCode!, displayName: 'Ana');
    final pending = await snapshotWhere(
        master, (p) => p.state == ParticipantState.pendingApproval);
    final id = pending.participants.single.id;
    final dropped = snapshotWhere(
        master, (p) => p.id == id && p.state == ParticipantState.disconnected);

    await joiner.cancelJoin();

    expect(failureCode(await join.timeout(const Duration(seconds: 5))),
        'session.join-cancelled');
    await dropped;
  });

  test('"Sair da sala" drops the singer from the room (ROOM-43)', () async {
    final master = controller('marina');
    final joiner = controller('ana');
    final room = await open(master, joiner);
    expect((await joined(master, joiner, room)).isSuccess, isTrue);
    var lost = 0;
    joiner.masterConnectionLost.listen((_) => lost++);

    final dropped =
        snapshotWhere(master, (p) => p.state == ParticipantState.disconnected);

    await joiner.leaveRoom();

    await dropped;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(lost, 0, reason: 'leaving on purpose is not a lost room');
  });

  test('the master ending the room tells the singer once (ROOM-44)', () async {
    final master = controller('marina');
    final joiner = controller('ana');
    final room = await open(master, joiner);
    expect((await joined(master, joiner, room)).isSuccess, isTrue);
    var lost = 0;
    final first = joiner.masterConnectionLost.first;
    joiner.masterConnectionLost.listen((_) => lost++);

    await master.endRoom();

    await first.timeout(const Duration(seconds: 5));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(lost, 1);
  });

  test('a room that left the network can no longer be asked', () async {
    final joiner = controller('ana');
    final events = joiner.discoverRooms().take(2).toList();
    const id = RoomId('gone');
    bus.add(const DiscoveredRoom(id: id, host: '127.0.0.1', port: 1));
    bus.add(const DiscoveredRoom(id: id, host: '', port: 0, available: false));
    await events.timeout(const Duration(seconds: 5));

    final result = await joiner.requestJoin(id, '1234', displayName: 'Ana');

    expect(failureCode(result), 'session.room-not-found');
  });
}
