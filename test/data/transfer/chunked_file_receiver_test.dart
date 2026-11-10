import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/data/session/room_application_message.dart';
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

/// Same connect+approve helper pattern as `room_session_controller_test.dart`
/// and `chunked_file_sender_test.dart`, for a single master+visitor pair.
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
  group('ChunkedFileReceiver (XFER-05, XFER-06, XFER-07, XFER-10)', () {
    test(
        'full happy path with ChunkedFileSender: reassembled file hash-matches and is promoted to its content-addressed path',
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

      final sourceDir = Directory.systemTemp.createTempSync('receiver_src');
      final storageRoot = Directory.systemTemp.createTempSync('receiver_store');
      addTearDown(() {
        sourceDir.deleteSync(recursive: true);
        storageRoot.deleteSync(recursive: true);
      });

      final fileBytes = Uint8List.fromList(List.generate(130, (i) => i % 256));
      final expectedSha256 = sha256.convert(fileBytes).toString();
      final sourceFile = File('${sourceDir.path}/track.bin')
        ..writeAsBytesSync(fileBytes);

      final receiver = ChunkedFileReceiver(
        controller: visitor,
        storageRoot: storageRoot,
      );
      final progressEvents = <TransferProgress>[];
      final receiveDone = receiver
          .receiveTrack(
            trackId: 'track-happy',
            expectedSha256: expectedSha256,
            totalSizeBytes: fileBytes.length,
            extension: 'bin',
          )
          .listen(progressEvents.add)
          .asFuture<void>();

      final sender = ChunkedFileSender(controller: master, chunkSize: 50);
      final sendResult = await sender.sendTrack(
        songId: 'song-1',
        track: SongTrack(
          id: 'track-happy',
          filePath: sourceFile.path,
          naipe: Naipe.soprano,
        ),
        to: participant.id,
      );
      expect(sendResult.isSuccess, isTrue);

      await receiveDone.timeout(const Duration(seconds: 5));

      expect(progressEvents.last.phase, equals(TransferPhase.available));
      final finalPath = LibraryStoragePaths.trackFilePath(
        root: storageRoot,
        sha256: expectedSha256,
        extension: 'bin',
      );
      final promotedFile = File(finalPath);
      expect(await promotedFile.exists(), isTrue);
      expect(await promotedFile.readAsBytes(), equals(fileBytes));
    });

    test(
        'a hash mismatch is never promoted; after exhausting whole-track retries it surfaces ValidationFailure(transfer.hash-mismatch)',
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
      final storageRoot = Directory.systemTemp.createTempSync('receiver_mismatch');
      addTearDown(() => storageRoot.deleteSync(recursive: true));

      const trackId = 'track-mismatch';
      const declaredSha256 = 'this-hash-will-never-match';
      final chunkBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      final receiver = ChunkedFileReceiver(
        controller: visitor,
        storageRoot: storageRoot,
        maxWholeTrackRetries: 2,
      );
      final progressEvents = <TransferProgress>[];
      final receiveDone = receiver
          .receiveTrack(
            trackId: trackId,
            expectedSha256: declaredSha256,
            totalSizeBytes: chunkBytes.length,
            extension: 'bin',
          )
          .listen(progressEvents.add)
          .asFuture<void>();

      // Drive 3 attempts (initial + 2 retries) manually: each attempt is a
      // fresh TransferBegin followed by the one chunk, mirroring what a real
      // resending sender does on a hash-mismatch signal.
      for (var attempt = 0; attempt < 3; attempt++) {
        await master.sendEnvelopeTo(
          participant.id,
          TransferBeginMessage(
            songId: 'song-1',
            trackId: trackId,
            totalSizeBytes: chunkBytes.length,
            sha256Declared: declaredSha256,
            chunkSize: 64 * 1024,
          ).encode(),
        );
        await master.sendEnvelopeTo(
          participant.id,
          ChunkDataMessage(trackId: trackId, chunkIndex: 0, bytes: chunkBytes)
              .encode(),
        );
        // Give the receiver time to hash-check and discard before the next
        // TransferBegin is sent, so each attempt is processed independently.
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }

      await receiveDone.timeout(const Duration(seconds: 5));

      expect(progressEvents.last.phase, equals(TransferPhase.failed));
      expect(
        progressEvents.last.failureCode,
        equals('transfer.hash-mismatch'),
      );
      final finalPath = LibraryStoragePaths.trackFilePath(
        root: storageRoot,
        sha256: declaredSha256,
        extension: 'bin',
      );
      expect(await File(finalPath).exists(), isFalse);
    });

    test(
        'a file already present at the final content-addressed path is never re-transferred (dedup skip, zero chunk writes)',
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

      await _connectAndApprove(master, visitor, bus);
      final storageRoot = Directory.systemTemp.createTempSync('receiver_dedup');
      addTearDown(() => storageRoot.deleteSync(recursive: true));

      const expectedSha256 = 'already-have-this-one';
      final finalPath = LibraryStoragePaths.trackFilePath(
        root: storageRoot,
        sha256: expectedSha256,
        extension: 'bin',
      );
      await File(finalPath).create(recursive: true);
      await File(finalPath).writeAsBytes([9, 9, 9]);

      var writeChunkCalls = 0;
      final receiver = ChunkedFileReceiver(
        controller: visitor,
        storageRoot: storageRoot,
        writeChunk: ({
          required partialFilePath,
          required chunkIndex,
          required chunkSize,
          required bytes,
        }) async {
          writeChunkCalls++;
        },
      );

      final progress = await receiver
          .receiveTrack(
            trackId: 'track-dedup',
            expectedSha256: expectedSha256,
            totalSizeBytes: 999999,
            extension: 'bin',
          )
          .toList()
          .timeout(const Duration(seconds: 2));

      expect(progress, hasLength(1));
      expect(progress.single.phase, equals(TransferPhase.available));
      expect(writeChunkCalls, equals(0));
    });

    test(
        'a write failure (simulated insufficient storage) aborts with StorageFailure(transfer.insufficient-storage) without affecting a concurrent transfer to another participant',
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

      // Subscribe both visitors' discovery streams before createRoom() so
      // the (broadcast) advertise event isn't missed for lack of a listener.
      final discoveredForA = StreamController<DiscoveredRoom>.broadcast();
      visitorA.discoverRooms().listen(discoveredForA.add);
      final discoveredRoomAFuture = discoveredForA.stream.first;
      final discoveredForB = StreamController<DiscoveredRoom>.broadcast();
      visitorB.discoverRooms().listen(discoveredForB.add);
      final discoveredRoomBFuture = discoveredForB.stream.first;

      await master.createRoom();
      await masterSnapshotQueue.moveNext();
      final code = masterSnapshotQueue.current.room.code;

      final discoveredRoomA =
          await discoveredRoomAFuture.timeout(const Duration(seconds: 5));
      final joinA = visitorA.requestJoin(discoveredRoomA.id, code);
      ParticipantSession? pendingA;
      while (pendingA == null) {
        await masterSnapshotQueue.moveNext();
        for (final p in masterSnapshotQueue.current.participants) {
          if (p.state == ParticipantState.pendingApproval) {
            pendingA = p;
          }
        }
      }
      await master.approve(pendingA.id);
      await joinA.timeout(const Duration(seconds: 5));

      final discoveredRoomB =
          await discoveredRoomBFuture.timeout(const Duration(seconds: 5));
      final joinB = visitorB.requestJoin(discoveredRoomB.id, code);
      ParticipantSession? pendingB;
      while (pendingB == null) {
        await masterSnapshotQueue.moveNext();
        for (final p in masterSnapshotQueue.current.participants) {
          if (p.state == ParticipantState.pendingApproval &&
              p.id != pendingA.id) {
            pendingB = p;
          }
        }
      }
      await master.approve(pendingB.id);
      await joinB.timeout(const Duration(seconds: 5));

      // Wait until both participants show connected (handshake complete)
      // before sending — sendEnvelopeTo requires a connected participant.
      var bothConnected = false;
      while (!bothConnected) {
        await masterSnapshotQueue.moveNext();
        final snapshot = masterSnapshotQueue.current;
        bothConnected = snapshot.participants
                .where((p) =>
                    p.id == pendingA!.id &&
                    p.state == ParticipantState.connected)
                .isNotEmpty &&
            snapshot.participants
                .where((p) =>
                    p.id == pendingB!.id &&
                    p.state == ParticipantState.connected)
                .isNotEmpty;
      }

      final storageRootA = Directory.systemTemp.createTempSync('receiver_fail_a');
      final storageRootB = Directory.systemTemp.createTempSync('receiver_ok_b');
      addTearDown(() {
        storageRootA.deleteSync(recursive: true);
        storageRootB.deleteSync(recursive: true);
      });

      final receiverA = ChunkedFileReceiver(
        controller: visitorA,
        storageRoot: storageRootA,
        writeChunk: ({
          required partialFilePath,
          required chunkIndex,
          required chunkSize,
          required bytes,
        }) async {
          throw const FileSystemException('simulated disk full');
        },
      );
      final chunkBytes = Uint8List.fromList([1, 2, 3]);
      final sha256ForB = sha256.convert(chunkBytes).toString();
      final receiverB = ChunkedFileReceiver(
        controller: visitorB,
        storageRoot: storageRootB,
      );

      final progressAFuture =
          receiverA.receiveTrack(
            trackId: 'track-fail',
            expectedSha256: 'does-not-matter',
            totalSizeBytes: chunkBytes.length,
          ).toList();
      final progressBFuture =
          receiverB.receiveTrack(
            trackId: 'track-ok',
            expectedSha256: sha256ForB,
            totalSizeBytes: chunkBytes.length,
          ).toList();

      await master.sendEnvelopeTo(
        pendingA.id,
        TransferBeginMessage(
          songId: 'song-1',
          trackId: 'track-fail',
          totalSizeBytes: chunkBytes.length,
          sha256Declared: 'does-not-matter',
          chunkSize: 64 * 1024,
        ).encode(),
      );
      await master.sendEnvelopeTo(
        pendingA.id,
        ChunkDataMessage(trackId: 'track-fail', chunkIndex: 0, bytes: chunkBytes)
            .encode(),
      );

      await master.sendEnvelopeTo(
        pendingB.id,
        TransferBeginMessage(
          songId: 'song-1',
          trackId: 'track-ok',
          totalSizeBytes: chunkBytes.length,
          sha256Declared: sha256ForB,
          chunkSize: 64 * 1024,
        ).encode(),
      );
      await master.sendEnvelopeTo(
        pendingB.id,
        ChunkDataMessage(trackId: 'track-ok', chunkIndex: 0, bytes: chunkBytes)
            .encode(),
      );

      final progressA =
          await progressAFuture.timeout(const Duration(seconds: 5));
      final progressB =
          await progressBFuture.timeout(const Duration(seconds: 5));

      expect(progressA.last.phase, equals(TransferPhase.failed));
      expect(
        progressA.last.failureCode,
        equals('transfer.insufficient-storage'),
      );
      expect(progressB.last.phase, equals(TransferPhase.available));
    });
  });
}
