import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/unit.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/data/session/room_application_message.dart';
import 'package:cantae/data/session/room_session_controller.dart';
import 'package:cantae/data/transfer/chunked_file_sender.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/domain/entities/song_track.dart';
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
  Future<Result<Unit, NetworkFailure>> advertise(
    RoomId id,
    int port,
    RoomAnnouncement announcement,
  ) async {
    _bus.add(DiscoveredRoom(id: id, host: '127.0.0.1', port: port));
    return const Result.success(Unit());
  }

  @override
  Stream<DiscoveredRoom> discover() => _bus.stream;

  @override
  Future<void> stopAdvertising() async {}
}

/// Connects [visitor] to [master], approves the join, and waits until the
/// master's snapshot shows the participant connected (handshake complete).
/// Same pattern as `room_session_controller_test.dart`'s private helper.
Future<ParticipantSession> _connectAndApprove(
  RoomSessionController master,
  RoomSessionController visitor,
  StreamController<DiscoveredRoom> bus,
) async {
  final masterSnapshots = StreamController<RoomSessionSnapshot>.broadcast();
  master.snapshots.listen(masterSnapshots.add);
  final masterSnapshotQueue = StreamIterator(masterSnapshots.stream);

  final discoveredRooms = StreamController<DiscoveredRoom>.broadcast();
  visitor.discoverRooms().listen(discoveredRooms.add);
  final discoveredRoomFuture = discoveredRooms.stream.first;

  await master.createRoom();
  await masterSnapshotQueue.moveNext();
  final code = masterSnapshotQueue.current.room.code;

  final discoveredRoom =
      await discoveredRoomFuture.timeout(const Duration(seconds: 5));
  final joinResultFuture = visitor.requestJoin(discoveredRoom.id, code);

  ParticipantSession? pending;
  while (pending == null) {
    await masterSnapshotQueue.moveNext();
    for (final participant in masterSnapshotQueue.current.participants) {
      if (participant.state == ParticipantState.pendingApproval) {
        pending = participant;
        break;
      }
    }
  }
  await master.approve(pending.id);
  await joinResultFuture.timeout(const Duration(seconds: 5));

  ParticipantSession? connected;
  while (connected == null || connected.state != ParticipantState.connected) {
    await masterSnapshotQueue.moveNext();
    for (final participant in masterSnapshotQueue.current.participants) {
      if (participant.id == pending.id) {
        connected = participant;
      }
    }
  }
  return connected;
}

void main() {
  group('ChunkedFileSender (XFER-01, XFER-02, XFER-03, XFER-08)', () {
    test(
        'sends TransferBegin, every chunk in order, then TransferComplete, over real loopback TCP, with a receiver ACKing each chunk',
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

      final participant = await _connectAndApprove(master, visitor, bus);

      final tempFile = File(
        '${Directory.systemTemp.createTempSync('chunked_sender_test').path}/track.bin',
      );
      // 25 bytes with a 10-byte chunk size => chunks of 10, 10, 5 (3 chunks).
      await tempFile.writeAsBytes(List.generate(25, (i) => i % 256));
      addTearDown(() => tempFile.parent.deleteSync(recursive: true));

      final receivedChunkIndexesInOrder = <int>[];
      var transferCompleteReceived = false;
      visitor.applicationMessages.listen((event) async {
        final message = RoomApplicationMessage.decode(event.$2);
        if (message is ChunkDataMessage) {
          receivedChunkIndexesInOrder.add(message.chunkIndex);
          await visitor.sendEnvelope(
            ChunkAckMessage(
              trackId: message.trackId,
              chunkIndex: message.chunkIndex,
            ).encode(),
          );
        }
        if (message is TransferCompleteMessage) {
          transferCompleteReceived = true;
        }
      });

      final sender = ChunkedFileSender(controller: master, chunkSize: 10);
      final track = SongTrack(
        id: 'track-1',
        filePath: tempFile.path,
        naipe: Naipe.soprano,
      );

      final result = await sender.sendTrack(
        songId: 'song-1',
        track: track,
        to: participant.id,
      );

      expect(result.isSuccess, isTrue);
      expect(receivedChunkIndexesInOrder, equals([0, 1, 2]));

      // TransferComplete arrives asynchronously right after the last chunk's
      // ACK is processed by the sender; give the loopback round trip a short
      // window, well under the test's own timeout.
      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while (!transferCompleteReceived && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(transferCompleteReceived, isTrue);
    });

    test(
        'fails with NetworkFailure(transfer.chunk-delivery-failed) after exhausting retries on an unACKed chunk',
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

      final participant = await _connectAndApprove(master, visitor, bus);
      // No ACK listener on the visitor side at all — every chunk attempt
      // times out, so the sender must exhaust its bounded retries.

      final tempFile = File(
        '${Directory.systemTemp.createTempSync('chunked_sender_fail_test').path}/track.bin',
      );
      await tempFile.writeAsBytes(List.generate(5, (i) => i));
      addTearDown(() => tempFile.parent.deleteSync(recursive: true));

      final sender = ChunkedFileSender(
        controller: master,
        chunkSize: 10,
        maxAttemptsPerChunk: 3,
        ackTimeout: const Duration(milliseconds: 50),
      );
      final track = SongTrack(
        id: 'track-2',
        filePath: tempFile.path,
        naipe: Naipe.soprano,
      );

      final result = await sender.sendTrack(
        songId: 'song-1',
        track: track,
        to: participant.id,
      );

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) =>
            expect(f.code, equals('transfer.chunk-delivery-failed')),
      );
    });
  });
}
