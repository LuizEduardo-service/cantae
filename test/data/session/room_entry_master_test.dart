import 'dart:async';
import 'dart:typed_data';

import 'package:cantae/data/session/frame_codec.dart';
import 'package:cantae/data/session/room_session_controller.dart';
import 'package:cantae/data/session/session_wire_message.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/core/unit.dart';
import 'package:cantae/domain/session/handshake_service.dart';
import 'package:cantae/domain/session/ids.dart';
import 'package:cantae/domain/session/participant_session.dart';
import 'package:cantae/domain/session/room_discovery.dart';
import 'package:cantae/domain/session/room_entry_rules.dart';
import 'package:cantae/domain/session/session_transport.dart';
import 'package:cantae/infrastructure/network/tcp_session_transport.dart';
import 'package:flutter_test/flutter_test.dart';

// Failure modes, master side (ROOM-05, 09, 13, 15, 20, 21, 34, NET-01):
// - the announcement lacks the master's name, the song or the version, or
//   carries the code;
// - changing the song does not reach people searching;
// - an advertise failure (no local network permission) is reported as a
//   room that works;
// - "Recusar" or an expired request just drops the connection, so the
//   singer cannot tell it from a network problem;
// - a stalled handshake is reported to the singer as a refusal;
// - an app on another version gets in, or is told "wrong code";
// - a name from the network reaches the master's list unbounded.
class _BusDiscovery implements RoomDiscovery {
  _BusDiscovery(this.bus);

  final StreamController<DiscoveredRoom> bus;
  Result<Unit, NetworkFailure> advertiseResult = const Result.success(Unit());
  final announcements = <RoomAnnouncement>[];
  var stops = 0;

  @override
  Future<Result<Unit, NetworkFailure>> advertise(
    RoomId id,
    int port,
    RoomAnnouncement announcement,
  ) async {
    announcements.add(announcement);
    if (advertiseResult.isSuccess) {
      bus.add(DiscoveredRoom(
        id: id,
        host: '127.0.0.1',
        port: port,
        masterName: announcement.masterName,
        songName: announcement.songName,
      ));
    }
    return advertiseResult;
  }

  @override
  Stream<DiscoveredRoom> discover() => bus.stream;

  @override
  Future<void> stopAdvertising() async => stops++;
}

/// A bare TCP client that speaks the wire format by hand, to send what a
/// real controller never would (another version, no handshake answer).
class _RawClient {
  _RawClient._(this.transport, this.connection);

  final TcpSessionTransport transport;
  final ParticipantId connection;
  final frames = <SessionWireMessage>[];
  final closed = Completer<void>();
  final _reassembler = FrameReassembler();

  static Future<_RawClient> connect(int port) async {
    final transport = TcpSessionTransport();
    final connection = await transport.connect('127.0.0.1', port);
    final client = _RawClient._(transport, connection);
    transport.receive(connection).listen((chunk) {
      for (final frame in client._reassembler.addChunk(chunk)) {
        client.frames.add(SessionWireMessage.decode(frame));
      }
    });
    transport.closedConnections.listen((id) {
      if (id == connection && !client.closed.isCompleted) {
        client.closed.complete();
      }
    });
    return client;
  }

  Future<void> send(SessionWireMessage message) =>
      transport.send(connection, encodeFrame(message.encode()));
}

/// Real TCP whose sends take [delay], so a room tick lands mid-send.
class _SlowSendTransport implements SessionTransport {
  _SlowSendTransport(this.delay);

  final Duration delay;
  final _inner = TcpSessionTransport();

  @override
  Future<void> send(ParticipantId id, Uint8List bytes) async {
    await Future<void>.delayed(delay);
    await _inner.send(id, bytes);
  }

  @override
  Future<void> listen(int port) => _inner.listen(port);
  @override
  int get boundPort => _inner.boundPort;
  @override
  Future<ParticipantId> connect(String host, int port) =>
      _inner.connect(host, port);
  @override
  Stream<ParticipantId> get incomingConnections => _inner.incomingConnections;
  @override
  Stream<ParticipantId> get closedConnections => _inner.closedConnections;
  @override
  Stream<Uint8List> receive(ParticipantId id) => _inner.receive(id);
  @override
  Future<void> close(ParticipantId id) => _inner.close(id);
}

void main() {
  late StreamController<DiscoveredRoom> bus;
  late _BusDiscovery masterDiscovery;
  late RoomSessionController master;
  late DateTime fakeNow;
  final toDispose = <RoomSessionController>[];

  RoomSessionController controller(String id, RoomDiscovery discovery) {
    final c = RoomSessionController(
      transport: TcpSessionTransport(),
      discovery: discovery,
      handshakeService: HandshakeService(),
      selfDeviceId: DeviceId(id),
      now: () => fakeNow,
      tickInterval: const Duration(milliseconds: 20),
    );
    toDispose.add(c);
    return c;
  }

  setUp(() {
    fakeNow = DateTime(2026, 11, 26, 19);
    bus = StreamController<DiscoveredRoom>.broadcast();
    masterDiscovery = _BusDiscovery(bus);
    master = controller('master', masterDiscovery);
  });

  tearDown(() async {
    for (final c in toDispose) {
      c.dispose();
    }
    toDispose.clear();
    await bus.close();
  });

  Future<ParticipantSession> nextPending() async {
    final snapshot = await master.snapshots
        .firstWhere((s) => s.participants
            .any((p) => p.state == ParticipantState.pendingApproval))
        .timeout(const Duration(seconds: 5));
    return snapshot.participants
        .firstWhere((p) => p.state == ParticipantState.pendingApproval);
  }

  /// Creates the room and returns it as the Wi‑Fi announces it.
  Future<DiscoveredRoom> createAndFind() async {
    final found = bus.stream.first;
    expect((await master.createRoom(masterName: 'Marina')).isSuccess, isTrue);
    return found.timeout(const Duration(seconds: 5));
  }

  /// A singer controller that already saw the master's room.
  Future<(RoomSessionController, DiscoveredRoom)> singer() async {
    final joiner = controller('marina', _BusDiscovery(bus));
    final found = joiner.discoverRooms().first;
    final created = await master.createRoom(masterName: 'Marina');
    expect(created.isSuccess, isTrue);
    return (joiner, await found.timeout(const Duration(seconds: 5)));
  }

  String? failureCode(Result<Object?, Failure> r) =>
      r.when(success: (_) => null, failure: (f) => f.code);

  test('the announcement carries master, song and version, never the code',
      () async {
    final created =
        await master.createRoom(masterName: 'Marina', songName: 'Ave Verum');

    expect(created.isSuccess, isTrue);
    final announcement = masterDiscovery.announcements.single;
    expect(announcement.masterName, 'Marina');
    expect(announcement.songName, 'Ave Verum');
    expect(announcement.protocolVersion, roomProtocolVersion);
    expect(master.roomCode, matches(RegExp(r'^\d{4}$')));
  });

  test('changing the song announces the room again with the new song',
      () async {
    await master.createRoom(masterName: 'Marina');

    await master.updateAnnouncement(songName: 'Cantate Domino');

    expect(masterDiscovery.stops, 1);
    expect(masterDiscovery.announcements, hasLength(2));
    expect(masterDiscovery.announcements.last.masterName, 'Marina');
    expect(masterDiscovery.announcements.last.songName, 'Cantate Domino');
  });

  test('an advertise failure makes createRoom fail with the same code',
      () async {
    masterDiscovery.advertiseResult =
        Result.failure(NetworkFailure(code: 'discovery.permission-denied'));

    final created = await master.createRoom(masterName: 'Marina');

    expect(failureCode(created), 'discovery.permission-denied');
    expect(master.roomCode, isNull);
  });

  test('"Recusar" tells the singer the request was refused (ROOM-13)',
      () async {
    final (joiner, room) = await singer();
    final join = joiner.requestJoin(room.id, master.roomCode!);
    final pending = await nextPending();

    expect(master.reject(pending.id).isSuccess, isTrue);

    expect(failureCode(await join.timeout(const Duration(seconds: 5))),
        'session.rejected');
  });

  test(
      'a request left 60 s without an answer tells the singer it expired '
      '(ROOM-15, ROOM-35)', () async {
    final (joiner, room) = await singer();
    final join = joiner.requestJoin(room.id, master.roomCode!);
    await nextPending();

    fakeNow = fakeNow.add(const Duration(seconds: 61));

    expect(failureCode(await join.timeout(const Duration(seconds: 5))),
        'session.request-expired');
  });

  test('a stalled handshake only closes the connection, with no refusal',
      () async {
    final raw = await _RawClient.connect((await createAndFind()).port);
    await raw.send(JoinRequestMessage(
      deviceId: 'stuck',
      code: master.roomCode!,
      displayName: 'Bruno',
    ));
    final pending = await nextPending();
    await master.approve(pending.id);

    fakeNow = fakeNow.add(const Duration(seconds: 11));
    await raw.closed.future.timeout(const Duration(seconds: 5));

    expect(raw.frames.whereType<JoinRejectedMessage>(), isEmpty);
    expect(raw.frames.whereType<HandshakeInitMessage>(), hasLength(1));
  });

  test('another protocol version is refused as incompatible (ROOM-34)',
      () async {
    final raw = await _RawClient.connect((await createAndFind()).port);

    await raw.send(JoinRequestMessage(
      deviceId: 'old-app',
      code: master.roomCode!,
      protocolVersion: roomProtocolVersion + 1,
    ));
    await raw.closed.future.timeout(const Duration(seconds: 5));

    final refusal = raw.frames.whereType<JoinRejectedMessage>().single;
    expect(refusal.reasonCode, 'session.protocol-mismatch');
    expect(master.currentSnapshot!.participants, isEmpty);
  });

  test('a name from the network reaches the list cleaned and cut to 40',
      () async {
    final raw = await _RawClient.connect((await createAndFind()).port);

    await raw.send(JoinRequestMessage(
      deviceId: 'long',
      code: master.roomCode!,
      displayName: '\u0007${'b' * 200}',
    ));

    expect((await nextPending()).displayName, 'b' * 40);
  });

  test(
      'regression: a room tick during the refusal does not close the socket '
      'mid-send, and the singer still hears "Recusar"', () async {
    final slowMaster = RoomSessionController(
      transport: _SlowSendTransport(const Duration(milliseconds: 150)),
      discovery: masterDiscovery,
      handshakeService: HandshakeService(),
      selfDeviceId: const DeviceId('slow-master'),
      now: () => fakeNow,
      tickInterval: const Duration(milliseconds: 10),
    );
    toDispose.add(slowMaster);
    final joiner = controller('marina', _BusDiscovery(bus));
    final found = joiner.discoverRooms().first;
    await slowMaster.createRoom(masterName: 'Marina');
    final room = await found.timeout(const Duration(seconds: 5));
    final join = joiner.requestJoin(room.id, slowMaster.roomCode!);
    final pendingSnapshot = await slowMaster.snapshots
        .firstWhere((s) => s.participants
            .any((p) => p.state == ParticipantState.pendingApproval))
        .timeout(const Duration(seconds: 5));

    slowMaster.reject(pendingSnapshot.participants.single.id);

    expect(failureCode(await join.timeout(const Duration(seconds: 5))),
        'session.rejected');
  });
}
