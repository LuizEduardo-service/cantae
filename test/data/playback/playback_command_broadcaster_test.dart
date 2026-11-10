import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/data/playback/playback_command_broadcaster.dart';
import 'package:cantae/data/session/room_application_message.dart';
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

/// Replies to every `LatencyProbeMessage` with a matching
/// `LatencyProbeReplyMessage`, after an optional artificial delay — lets a
/// test force two participants to measure observably different latencies.
void _attachLatencyProbeResponder(
  RoomSessionController visitor, {
  Duration replyDelay = Duration.zero,
}) {
  visitor.applicationMessages.listen((event) async {
    final message = RoomApplicationMessage.decode(event.$2);
    if (message is LatencyProbeMessage) {
      if (replyDelay > Duration.zero) {
        await Future<void>.delayed(replyDelay);
      }
      await visitor.sendEnvelope(
        LatencyProbeReplyMessage(probeId: message.probeId).encode(),
      );
    }
  });
}

Future<DiscoveredRoom> _subscribeDiscovery(RoomSessionController visitor) {
  final discoveredRooms = StreamController<DiscoveredRoom>.broadcast();
  visitor.discoverRooms().listen(discoveredRooms.add);
  return discoveredRooms.stream.first.timeout(const Duration(seconds: 5));
}

Future<ParticipantSession> _joinAndApprove(
  RoomSessionController master,
  RoomSessionController visitor,
  StreamIterator<RoomSessionSnapshot> masterSnapshotQueue,
  String code,
  Future<DiscoveredRoom> discoveredRoomFuture,
) async {
  final discoveredRoom = await discoveredRoomFuture;
  final joinResultFuture = visitor.requestJoin(discoveredRoom.id, code);

  ParticipantSession? pending;
  while (pending == null) {
    await masterSnapshotQueue.moveNext();
    for (final p in masterSnapshotQueue.current.participants) {
      if (p.state == ParticipantState.pendingApproval) {
        pending = p;
      }
    }
  }
  await master.approve(pending.id);
  await joinResultFuture.timeout(const Duration(seconds: 5));

  ParticipantSession? connected;
  while (connected == null || connected.state != ParticipantState.connected) {
    await masterSnapshotQueue.moveNext();
    for (final p in masterSnapshotQueue.current.participants) {
      if (p.id == pending.id) {
        connected = p;
      }
    }
  }
  return connected;
}

void main() {
  group('PlaybackCommandBroadcaster (SYNC-02, SYNC-04, SYNC-07, SYNC-08)', () {
    test(
        'play() on a 3-device loopback room produces a distinct PlayCommandMessage per participant, each carrying its own latency-adjusted epoch',
        () async {
      final bus = StreamController<DiscoveredRoom>.broadcast();
      final master = RoomSessionController(
        transport: TcpSessionTransport(),
        discovery: _FakeRoomDiscovery(bus),
        handshakeService: HandshakeService(),
        selfDeviceId: const DeviceId('master-device'),
      );
      final visitorA = RoomSessionController(
        transport: TcpSessionTransport(),
        discovery: _FakeRoomDiscovery(bus),
        handshakeService: HandshakeService(),
        selfDeviceId: const DeviceId('visitor-a'),
      );
      final visitorB = RoomSessionController(
        transport: TcpSessionTransport(),
        discovery: _FakeRoomDiscovery(bus),
        handshakeService: HandshakeService(),
        selfDeviceId: const DeviceId('visitor-b'),
      );
      addTearDown(() {
        master.dispose();
        visitorA.dispose();
        visitorB.dispose();
        bus.close();
      });

      final masterSnapshots = StreamController<RoomSessionSnapshot>.broadcast();
      master.snapshots.listen(masterSnapshots.add);
      final masterSnapshotQueue = StreamIterator(masterSnapshots.stream);

      final discoveredForA = _subscribeDiscovery(visitorA);
      final discoveredForB = _subscribeDiscovery(visitorB);

      // Constructed before createRoom(): the broadcaster subscribes to
      // `controller.snapshots` (a non-buffering broadcast stream) in its own
      // constructor, so it must exist before the room-creation/join/approve
      // snapshot updates it needs to see are emitted.
      final broadcaster = PlaybackCommandBroadcaster(controller: master);
      addTearDown(broadcaster.dispose);

      await master.createRoom();
      await masterSnapshotQueue.moveNext();
      final code = masterSnapshotQueue.current.room.code;

      final a = await _joinAndApprove(
          master, visitorA, masterSnapshotQueue, code, discoveredForA);
      final b = await _joinAndApprove(
          master, visitorB, masterSnapshotQueue, code, discoveredForB);

      // Force observably different round-trip latencies for A and B.
      _attachLatencyProbeResponder(visitorA);
      _attachLatencyProbeResponder(visitorB,
          replyDelay: const Duration(milliseconds: 60));

      final playCommandsByParticipant = <ParticipantId, PlayCommandMessage>{};
      visitorA.applicationMessages.listen((event) {
        final message = RoomApplicationMessage.decode(event.$2);
        if (message is PlayCommandMessage) {
          playCommandsByParticipant[a.id] = message;
        }
      });
      visitorB.applicationMessages.listen((event) {
        final message = RoomApplicationMessage.decode(event.$2);
        if (message is PlayCommandMessage) {
          playCommandsByParticipant[b.id] = message;
        }
      });

      await broadcaster.play('song-1');

      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (playCommandsByParticipant.length < 2 &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      expect(playCommandsByParticipant.containsKey(a.id), isTrue);
      expect(playCommandsByParticipant.containsKey(b.id), isTrue);
      expect(playCommandsByParticipant[a.id]!.songId, equals('song-1'));
      expect(playCommandsByParticipant[b.id]!.songId, equals('song-1'));
      // B's artificially higher round-trip latency must produce a later
      // (or equal, in the unlikely case both measured near-zero) scheduled
      // epoch than A's — proving the epoch is genuinely per-participant,
      // not a single shared value broadcast to everyone.
      expect(
        playCommandsByParticipant[b.id]!.masterSendEpochMs,
        greaterThan(playCommandsByParticipant[a.id]!.masterSendEpochMs),
      );
    });

    test('pause(), stop(), and repositionToLoopStart() each send their own command type with a probe-adjusted epoch',
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

      final discoveredRoomFuture = _subscribeDiscovery(visitor);

      final broadcaster = PlaybackCommandBroadcaster(controller: master);
      addTearDown(broadcaster.dispose);

      await master.createRoom();
      await masterSnapshotQueue.moveNext();
      final code = masterSnapshotQueue.current.room.code;
      await _joinAndApprove(
          master, visitor, masterSnapshotQueue, code, discoveredRoomFuture);

      _attachLatencyProbeResponder(visitor);

      final received = <RoomApplicationMessage>[];
      visitor.applicationMessages.listen((event) {
        final message = RoomApplicationMessage.decode(event.$2);
        if (message is PauseCommandMessage ||
            message is StopCommandMessage ||
            message is LoopRepositionMessage) {
          received.add(message);
        }
      });

      await broadcaster.pause();
      await broadcaster.stop();
      await broadcaster.repositionToLoopStart();

      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (received.length < 3 && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      expect(received.whereType<PauseCommandMessage>(), hasLength(1));
      expect(received.whereType<StopCommandMessage>(), hasLength(1));
      expect(received.whereType<LoopRepositionMessage>(), hasLength(1));
    });

    test(
        'a visitor-originated envelope with requiresMasterRole: true is rejected at the existing envelope gate, regardless of payload shape (regression of T8 coverage)',
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

      final discoveredRoomFuture = _subscribeDiscovery(visitor);
      await master.createRoom();
      await masterSnapshotQueue.moveNext();
      final code = masterSnapshotQueue.current.room.code;
      await _joinAndApprove(
          master, visitor, masterSnapshotQueue, code, discoveredRoomFuture);

      final received = <RoomApplicationMessage>[];
      master.applicationMessages.listen(
        (event) => received.add(RoomApplicationMessage.decode(event.$2)),
      );

      final forgedPlayCommand = PlayCommandMessage(
        songId: 'forged-song',
        masterSendEpochMs: DateTime.now().millisecondsSinceEpoch,
      ).encode();
      final sendResult = await visitor.sendEnvelope(
        forgedPlayCommand,
        requiresMasterRole: true,
      );
      expect(sendResult.isSuccess, isTrue,
          reason: 'the wire send itself succeeds; rejection happens at the role gate on receipt');

      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(received, isEmpty);
    });
  });
}
