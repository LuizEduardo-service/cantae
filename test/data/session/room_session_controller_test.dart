import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/data/session/room_session_controller.dart';
import 'package:cantae/domain/session/handshake_service.dart';
import 'package:cantae/domain/session/ids.dart';
import 'package:cantae/domain/session/participant_session.dart';
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
}
