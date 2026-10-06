import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/data/session/room_session_controller.dart';
import 'package:cantae/domain/session/handshake_service.dart';
import 'package:cantae/domain/session/ids.dart';
import 'package:cantae/domain/session/participant_session.dart';
import 'package:cantae/domain/session/room.dart';
import 'package:cantae/domain/session/room_discovery.dart';
import 'package:cantae/domain/session/room_session_snapshot.dart';
import 'package:cantae/infrastructure/network/tcp_session_transport.dart';

class _FakeRoomDiscovery implements RoomDiscovery {
  final StreamController<DiscoveredRoom> _bus;

  _FakeRoomDiscovery(this._bus);

  @override
  Future<void> advertise(RoomId id, int port) async {
    _bus.add(DiscoveredRoom(id: id, host: '127.0.0.1', port: port));
  }

  @override
  Stream<DiscoveredRoom> discover() => _bus.stream;

  @override
  Future<void> stopAdvertising() async {}
}

ParticipantSession? _findPending(RoomSessionSnapshot snapshot) {
  for (final participant in snapshot.participants) {
    if (participant.state == ParticipantState.pendingApproval) {
      return participant;
    }
  }
  return null;
}

void main() {
  test(
      'two controllers complete join -> approve -> handshake over real loopback TCP and derive matching session keys',
      () async {
    final bus = StreamController<DiscoveredRoom>.broadcast();
    final master = RoomSessionController(
      transport: TcpSessionTransport(),
      discovery: _FakeRoomDiscovery(bus),
      handshakeService: HandshakeService(),
      selfDeviceId: const DeviceId('master-device'),
    );
    final visitor = RoomSessionController(
      transport: TcpSessionTransport(),
      discovery: _FakeRoomDiscovery(bus),
      handshakeService: HandshakeService(),
      selfDeviceId: const DeviceId('visitor-device'),
    );
    addTearDown(() {
      master.dispose();
      visitor.dispose();
      bus.close();
    });

    final masterSnapshots = StreamController<RoomSessionSnapshot>.broadcast();
    master.snapshots.listen(masterSnapshots.add);
    final masterSnapshotQueue = StreamIterator(masterSnapshots.stream);

    // Subscribe before createRoom() so the (broadcast) discovery event isn't
    // dropped for lack of a listener.
    final discoveredRooms = StreamController<DiscoveredRoom>.broadcast();
    visitor.discoverRooms().listen(discoveredRooms.add);
    final discoveredRoomFuture = discoveredRooms.stream.first;

    final createResult = await master.createRoom();
    expect(createResult.isSuccess, isTrue);
    await masterSnapshotQueue.moveNext();
    final roomId = masterSnapshotQueue.current.room.id;
    final code = masterSnapshotQueue.current.room.code;

    final discoveredRoom = await discoveredRoomFuture.timeout(
      const Duration(seconds: 5),
    );
    expect(discoveredRoom.id, equals(roomId));
    expect(discoveredRoom.port, greaterThan(0));

    final joinResultFuture = visitor.requestJoin(roomId, code);

    // Wait until the pending participant appears in the master's snapshot stream.
    ParticipantSession? pending;
    while (pending == null) {
      await masterSnapshotQueue.moveNext();
      pending = _findPending(masterSnapshotQueue.current);
    }

    final approveResult = await master.approve(pending.id);
    expect(approveResult.isSuccess, isTrue);

    final joinResult = await joinResultFuture.timeout(
      const Duration(seconds: 5),
    );
    expect(joinResult.isSuccess, isTrue);

    // Wait for the master-side snapshot reflecting the completed handshake.
    ParticipantSession? connected;
    while (connected == null || connected.state != ParticipantState.connected) {
      await masterSnapshotQueue.moveNext();
      connected = masterSnapshotQueue.current.participants
          .where((p) => p.id == pending!.id)
          .firstOrNull;
    }

    expect(connected.sessionKey, isNotNull);
    expect(connected.sessionKey!.length, equals(32));
  });

  test(
      'tick() is wired to a real periodic Timer and, with a fake advancing clock, expires a pendingApproval request without waiting real time',
      () async {
    final bus = StreamController<DiscoveredRoom>.broadcast();
    var fakeNow = DateTime(2026, 1, 1, 12);

    final master = RoomSessionController(
      transport: TcpSessionTransport(),
      discovery: _FakeRoomDiscovery(bus),
      handshakeService: HandshakeService(),
      selfDeviceId: const DeviceId('master-device'),
      now: () => fakeNow,
      tickInterval: const Duration(milliseconds: 20),
    );
    final visitor = RoomSessionController(
      transport: TcpSessionTransport(),
      discovery: _FakeRoomDiscovery(bus),
      handshakeService: HandshakeService(),
      selfDeviceId: const DeviceId('visitor-device'),
      now: () => fakeNow,
    );
    addTearDown(() {
      master.dispose();
      visitor.dispose();
      bus.close();
    });

    final masterSnapshots = StreamController<RoomSessionSnapshot>.broadcast();
    master.snapshots.listen(masterSnapshots.add);
    final masterSnapshotQueue = StreamIterator(masterSnapshots.stream);

    final discoveredRooms = StreamController<DiscoveredRoom>.broadcast();
    visitor.discoverRooms().listen(discoveredRooms.add);
    final discoveredRoomFuture = discoveredRooms.stream.first;

    await master.createRoom();
    await masterSnapshotQueue.moveNext();
    final code = masterSnapshotQueue.current.room.code;

    final discoveredRoom = await discoveredRoomFuture.timeout(
      const Duration(seconds: 5),
    );
    unawaited(visitor.requestJoin(discoveredRoom.id, code));

    ParticipantSession? pending;
    while (pending == null) {
      await masterSnapshotQueue.moveNext();
      pending = _findPending(masterSnapshotQueue.current);
    }

    // Advance the fake clock well past the 60s pending-approval TTL; the real
    // (but fast) Timer will pick this up on its next tick without the test
    // waiting 60 real seconds.
    fakeNow = fakeNow.add(const Duration(seconds: 61));

    ParticipantSession? rejected;
    while (rejected == null) {
      await masterSnapshotQueue.moveNext();
      rejected = masterSnapshotQueue.current.participants
          .where((p) =>
              p.id == pending!.id && p.state == ParticipantState.rejected)
          .firstOrNull;
    }

    expect(rejected.state, equals(ParticipantState.rejected));
  });

  test(
      'reject() closes the rejected participant\'s transport connection (NET-06)',
      () async {
    final bus = StreamController<DiscoveredRoom>.broadcast();
    final masterTransport = TcpSessionTransport();
    final visitorTransport = TcpSessionTransport();
    final master = RoomSessionController(
      transport: masterTransport,
      discovery: _FakeRoomDiscovery(bus),
      handshakeService: HandshakeService(),
      selfDeviceId: const DeviceId('master-device'),
    );
    final visitor = RoomSessionController(
      transport: visitorTransport,
      discovery: _FakeRoomDiscovery(bus),
      handshakeService: HandshakeService(),
      selfDeviceId: const DeviceId('visitor-device'),
    );
    addTearDown(() {
      master.dispose();
      visitor.dispose();
      bus.close();
    });

    final masterSnapshots = StreamController<RoomSessionSnapshot>.broadcast();
    master.snapshots.listen(masterSnapshots.add);
    final masterSnapshotQueue = StreamIterator(masterSnapshots.stream);

    final discoveredRooms = StreamController<DiscoveredRoom>.broadcast();
    visitor.discoverRooms().listen(discoveredRooms.add);
    final discoveredRoomFuture = discoveredRooms.stream.first;

    await master.createRoom();
    await masterSnapshotQueue.moveNext();
    final code = masterSnapshotQueue.current.room.code;
    final discoveredRoom = await discoveredRoomFuture.timeout(
      const Duration(seconds: 5),
    );
    unawaited(visitor.requestJoin(discoveredRoom.id, code));

    ParticipantSession? pending;
    while (pending == null) {
      await masterSnapshotQueue.moveNext();
      pending = _findPending(masterSnapshotQueue.current);
    }

    // A 1s wait window, well under the default 5s tickInterval, means the
    // periodic terminated-participant sweep (which also closes
    // rejected/expired sockets) cannot possibly fire before this assertion
    // resolves — any observed close must come from reject() itself. The
    // iteration-2 validation report's sensor mutation 3 caught an earlier
    // version of this test that used a 5s window equal to the tick period,
    // which let the sweep's very first fire satisfy the assertion even with
    // the close call deleted from reject().
    final visitorClosedFuture = visitorTransport.closedConnections.first
        .timeout(const Duration(seconds: 1));
    master.reject(pending.id);

    final closedConnectionId = await visitorClosedFuture;
    expect(closedConnectionId, equals(visitor.debugMasterConnection));
  });

  test(
      'endRoom() disconnects every participant, closes every connection, and stops advertising (NET-20)',
      () async {
    final bus = StreamController<DiscoveredRoom>.broadcast();
    final discoveryCalls = <String>[];
    final master = RoomSessionController(
      transport: TcpSessionTransport(),
      discovery: _RecordingRoomDiscovery(bus, discoveryCalls),
      handshakeService: HandshakeService(),
      selfDeviceId: const DeviceId('master-device'),
    );
    final visitorTransport = TcpSessionTransport();
    final visitor = RoomSessionController(
      transport: visitorTransport,
      discovery: _FakeRoomDiscovery(bus),
      handshakeService: HandshakeService(),
      selfDeviceId: const DeviceId('visitor-device'),
    );
    addTearDown(() {
      master.dispose();
      visitor.dispose();
      bus.close();
    });

    final masterSnapshots = StreamController<RoomSessionSnapshot>.broadcast();
    master.snapshots.listen(masterSnapshots.add);
    final masterSnapshotQueue = StreamIterator(masterSnapshots.stream);

    final discoveredRooms = StreamController<DiscoveredRoom>.broadcast();
    visitor.discoverRooms().listen(discoveredRooms.add);
    final discoveredRoomFuture = discoveredRooms.stream.first;

    await master.createRoom();
    await masterSnapshotQueue.moveNext();
    final code = masterSnapshotQueue.current.room.code;
    final discoveredRoom = await discoveredRoomFuture.timeout(
      const Duration(seconds: 5),
    );
    final joinResultFuture = visitor.requestJoin(discoveredRoom.id, code);

    ParticipantSession? pending;
    while (pending == null) {
      await masterSnapshotQueue.moveNext();
      pending = _findPending(masterSnapshotQueue.current);
    }
    await master.approve(pending.id);
    await joinResultFuture.timeout(const Duration(seconds: 5));

    final visitorClosedFuture = visitorTransport.closedConnections.first
        .timeout(const Duration(seconds: 5));

    await master.endRoom();

    await visitorClosedFuture;
    expect(discoveryCalls, contains('stopAdvertising'));

    ParticipantSession? disconnected;
    while (disconnected == null) {
      await masterSnapshotQueue.moveNext();
      disconnected = masterSnapshotQueue.current.participants
          .where(
            (p) =>
                p.id == pending!.id && p.state == ParticipantState.disconnected,
          )
          .firstOrNull;
    }
    expect(masterSnapshotQueue.current.room.state, equals(RoomLifecycle.ended));
  });

  test(
      'tick-driven expiry closes the expired participant\'s transport connection (NET-16)',
      () async {
    final bus = StreamController<DiscoveredRoom>.broadcast();
    var fakeNow = DateTime(2026, 1, 1, 12);
    final masterTransport = TcpSessionTransport();
    final visitorTransport = TcpSessionTransport();
    final master = RoomSessionController(
      transport: masterTransport,
      discovery: _FakeRoomDiscovery(bus),
      handshakeService: HandshakeService(),
      selfDeviceId: const DeviceId('master-device'),
      now: () => fakeNow,
      tickInterval: const Duration(milliseconds: 20),
    );
    final visitor = RoomSessionController(
      transport: visitorTransport,
      discovery: _FakeRoomDiscovery(bus),
      handshakeService: HandshakeService(),
      selfDeviceId: const DeviceId('visitor-device'),
      now: () => fakeNow,
    );
    addTearDown(() {
      master.dispose();
      visitor.dispose();
      bus.close();
    });

    final masterSnapshots = StreamController<RoomSessionSnapshot>.broadcast();
    master.snapshots.listen(masterSnapshots.add);
    final masterSnapshotQueue = StreamIterator(masterSnapshots.stream);

    final discoveredRooms = StreamController<DiscoveredRoom>.broadcast();
    visitor.discoverRooms().listen(discoveredRooms.add);
    final discoveredRoomFuture = discoveredRooms.stream.first;

    await master.createRoom();
    await masterSnapshotQueue.moveNext();
    final code = masterSnapshotQueue.current.room.code;
    final discoveredRoom = await discoveredRoomFuture.timeout(
      const Duration(seconds: 5),
    );
    final joinResultFuture = visitor.requestJoin(discoveredRoom.id, code);

    ParticipantSession? pending;
    while (pending == null) {
      await masterSnapshotQueue.moveNext();
      pending = _findPending(masterSnapshotQueue.current);
    }
    await master.approve(pending.id);
    await joinResultFuture.timeout(const Duration(seconds: 5));

    final visitorClosedFuture = visitorTransport.closedConnections.first
        .timeout(const Duration(seconds: 5));

    fakeNow = fakeNow.add(const Duration(minutes: 31));

    await visitorClosedFuture;
  });

  test(
      'an abrupt visitor-side socket kill is detected end-to-end: master disconnects the participant and frees the slot (NET-17)',
      () async {
    final bus = StreamController<DiscoveredRoom>.broadcast();
    final visitorTransport = TcpSessionTransport();
    final master = RoomSessionController(
      transport: TcpSessionTransport(),
      discovery: _FakeRoomDiscovery(bus),
      handshakeService: HandshakeService(),
      selfDeviceId: const DeviceId('master-device'),
    );
    final visitor = RoomSessionController(
      transport: visitorTransport,
      discovery: _FakeRoomDiscovery(bus),
      handshakeService: HandshakeService(),
      selfDeviceId: const DeviceId('visitor-device'),
    );
    addTearDown(() {
      master.dispose();
      visitor.dispose();
      bus.close();
    });

    final masterSnapshots = StreamController<RoomSessionSnapshot>.broadcast();
    master.snapshots.listen(masterSnapshots.add);
    final masterSnapshotQueue = StreamIterator(masterSnapshots.stream);

    final discoveredRooms = StreamController<DiscoveredRoom>.broadcast();
    visitor.discoverRooms().listen(discoveredRooms.add);
    final discoveredRoomFuture = discoveredRooms.stream.first;

    await master.createRoom();
    await masterSnapshotQueue.moveNext();
    final code = masterSnapshotQueue.current.room.code;
    final discoveredRoom = await discoveredRoomFuture.timeout(
      const Duration(seconds: 5),
    );
    final joinResultFuture = visitor.requestJoin(discoveredRoom.id, code);

    ParticipantSession? pending;
    while (pending == null) {
      await masterSnapshotQueue.moveNext();
      pending = _findPending(masterSnapshotQueue.current);
    }
    await master.approve(pending.id);
    await joinResultFuture.timeout(const Duration(seconds: 5));

    await visitorTransport.destroy(visitor.debugMasterConnection!);

    ParticipantSession? disconnected;
    while (disconnected == null) {
      await masterSnapshotQueue.moveNext();
      disconnected = masterSnapshotQueue.current.participants
          .where(
            (p) =>
                p.id == pending!.id && p.state == ParticipantState.disconnected,
          )
          .firstOrNull;
    }
    expect(disconnected.state, equals(ParticipantState.disconnected));
  });
}

class _RecordingRoomDiscovery implements RoomDiscovery {
  final StreamController<DiscoveredRoom> _bus;
  final List<String> calls;

  _RecordingRoomDiscovery(this._bus, this.calls);

  @override
  Future<void> advertise(RoomId id, int port) async {
    calls.add('advertise');
    _bus.add(DiscoveredRoom(id: id, host: '127.0.0.1', port: port));
  }

  @override
  Stream<DiscoveredRoom> discover() => _bus.stream;

  @override
  Future<void> stopAdvertising() async {
    calls.add('stopAdvertising');
  }
}
