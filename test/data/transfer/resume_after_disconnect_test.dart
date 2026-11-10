import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/data/session/room_session_controller.dart';
import 'package:cantae/data/transfer/chunked_file_receiver.dart';
import 'package:cantae/data/transfer/chunked_file_sender.dart';
import 'package:cantae/data/transfer/library_storage_paths.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/domain/entities/song_track.dart';
import 'package:cantae/domain/session/handshake_service.dart';
import 'package:cantae/domain/session/ids.dart';
import 'package:cantae/domain/session/participant_session.dart';
import 'package:cantae/domain/session/room_discovery.dart';
import 'package:cantae/domain/session/room_session_snapshot.dart';
import 'package:cantae/domain/transfer/chunk_planner.dart';
import 'package:cantae/domain/transfer/file_transfer_state.dart';
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

void main() {
  test(
      'a transfer interrupted by a dropped connection resumes from the last ACKed chunk after reconnect, not from zero (XFER-04)',
      () async {
    final bus = StreamController<DiscoveredRoom>.broadcast();
    final master = RoomSessionController(
      transport: TcpSessionTransport(),
      discovery: _FakeRoomDiscovery(bus),
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
    final firstDiscoveryFuture = discoveredRooms.stream.first;

    await master.createRoom();
    await masterSnapshotQueue.moveNext();
    final roomId = masterSnapshotQueue.current.room.id;
    final code = masterSnapshotQueue.current.room.code;

    final discoveredRoom =
        await firstDiscoveryFuture.timeout(const Duration(seconds: 5));
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
    final participantId = connected.id;

    final storageRoot =
        Directory.systemTemp.createTempSync('resume_after_disconnect');
    final sourceDir =
        Directory.systemTemp.createTempSync('resume_after_disconnect_src');
    addTearDown(() {
      storageRoot.deleteSync(recursive: true);
      sourceDir.deleteSync(recursive: true);
    });

    // A 500-byte file with a 50-byte chunk size => 10 chunks total.
    final fileBytes = Uint8List.fromList(List.generate(500, (i) => i % 256));
    final expectedSha256 = sha256.convert(fileBytes).toString();
    final sourceFile = File('${sourceDir.path}/track.bin')
      ..writeAsBytesSync(fileBytes);
    final track = SongTrack(
      id: 'track-resume',
      filePath: sourceFile.path,
      naipe: Naipe.soprano,
    );
    final totalChunks = ChunkPlanner.chunkCount(
      totalSizeBytes: fileBytes.length,
      chunkSize: 50,
    );
    expect(totalChunks, equals(10));

    // One long-lived receiveTrack() call, bound to the same `visitor`
    // controller object for the whole test — its in-memory progress
    // (receivedChunks) survives the connection drop below untouched, which
    // is what lets the second sendTrack() call resume instead of
    // restarting: the resend of TransferBegin on the resumed attempt finds
    // chunkSize/receivedChunks already populated from the first attempt.
    final receiver = ChunkedFileReceiver(
      controller: visitor,
      storageRoot: storageRoot,
    );
    final progressEvents = <TransferProgress>[];
    receiver
        .receiveTrack(
          trackId: track.id,
          expectedSha256: expectedSha256,
          totalSizeBytes: fileBytes.length,
          extension: 'bin',
        )
        .listen(progressEvents.add);

    final sender = ChunkedFileSender(
      controller: master,
      chunkSize: 50,
      maxAttemptsPerChunk: 2,
      ackTimeout: const Duration(milliseconds: 150),
    );

    final firstAttempt = sender.sendTrack(
      songId: 'song-1',
      track: track,
      to: participantId,
    );

    // Let a handful of chunks land, then abruptly destroy the visitor's
    // socket (simulating a Wi-Fi drop) mid-transfer.
    while (progressEvents
            .where((p) => p.phase == TransferPhase.inProgress)
            .length <
        3) {
      await Future<void>.delayed(const Duration(milliseconds: 15));
    }
    final chunksAckedBeforeDrop = progressEvents
        .where((p) => p.phase == TransferPhase.inProgress)
        .length;
    expect(chunksAckedBeforeDrop, greaterThan(0));
    expect(chunksAckedBeforeDrop, lessThan(totalChunks));

    await visitorTransport.destroy(visitor.debugMasterConnection!);

    final firstResult = await firstAttempt;
    expect(
      firstResult.isFailure,
      isTrue,
      reason: 'the dropped connection must fail the in-flight sendTrack call',
    );

    // Reconnect: the SAME `visitor` controller object rejoins the SAME
    // room; master re-approves, and a fresh handshake re-derives a session
    // key — `visitor.applicationMessages` (the stream the long-lived
    // receiver is already listening to) resumes emitting once that
    // handshake completes.
    final rejoinResultFuture = visitor.requestJoin(roomId, code);
    ParticipantSession? pendingAgain;
    while (pendingAgain == null) {
      await masterSnapshotQueue.moveNext();
      for (final p in masterSnapshotQueue.current.participants) {
        if (p.state == ParticipantState.pendingApproval) {
          pendingAgain = p;
        }
      }
    }
    await master.approve(pendingAgain.id);
    await rejoinResultFuture.timeout(const Duration(seconds: 5));

    ParticipantSession? reconnected;
    while (reconnected == null ||
        reconnected.state != ParticipantState.connected) {
      await masterSnapshotQueue.moveNext();
      for (final p in masterSnapshotQueue.current.participants) {
        if (p.id == pendingAgain.id) {
          reconnected = p;
        }
      }
    }

    final secondAttempt = await sender.sendTrack(
      songId: 'song-1',
      track: track,
      to: reconnected.id,
    );
    expect(secondAttempt.isSuccess, isTrue);

    final totalChunksAcked =
        progressEvents.where((p) => p.phase == TransferPhase.inProgress).length;
    final chunksSentInSecondAttempt = totalChunksAcked - chunksAckedBeforeDrop;

    expect(
      chunksSentInSecondAttempt,
      lessThan(totalChunks),
      reason:
          'resume must not resend every chunk from zero after a reconnect',
    );

    final finalPath = LibraryStoragePaths.trackFilePath(
      root: storageRoot,
      sha256: expectedSha256,
      extension: 'bin',
    );
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (!await File(finalPath).exists() &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(await File(finalPath).exists(), isTrue);
    expect(await File(finalPath).readAsBytes(), equals(fileBytes));
  });
}
