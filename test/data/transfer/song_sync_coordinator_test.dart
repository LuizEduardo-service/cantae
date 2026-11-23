import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/data/session/room_application_message.dart';
import 'package:cantae/data/session/room_session_controller.dart';
import 'package:cantae/data/transfer/chunked_file_sender.dart';
import 'package:cantae/data/transfer/song_sync_coordinator.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/domain/entities/song.dart';
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
  Future<void> advertise(RoomId id, int port) async {
    _bus.add(DiscoveredRoom(id: id, host: '127.0.0.1', port: port));
  }

  @override
  Stream<DiscoveredRoom> discover() => _bus.stream;

  @override
  Future<void> stopAdvertising() async {}
}

/// Attaches a minimal stub receiver to [visitor] that ACKs every chunk
/// immediately (optionally delayed by [ackDelay]) — enough to let a real
/// `ChunkedFileSender` complete, without pulling in the full
/// `ChunkedFileReceiver` machinery this test doesn't need.
void _attachStubReceiver(
  RoomSessionController visitor,
  List<String> beginTrackIdsSeen, {
  Duration ackDelay = Duration.zero,
}) {
  visitor.applicationMessages.listen((event) async {
    final message = RoomApplicationMessage.decode(event.$2);
    if (message is TransferBeginMessage) {
      beginTrackIdsSeen.add(message.trackId);
      return;
    }
    if (message is ChunkDataMessage) {
      if (ackDelay > Duration.zero) {
        await Future<void>.delayed(ackDelay);
      }
      await visitor.sendEnvelope(
        ChunkAckMessage(
                trackId: message.trackId, chunkIndex: message.chunkIndex)
            .encode(),
      );
    }
  });
}

/// Subscribes [visitor]'s discovery stream and returns a future for its
/// first discovered room. Must be called BEFORE `master.createRoom()` —
/// `advertise()` fires once, synchronously, during room creation, and the
/// shared (broadcast) discovery bus does not buffer for late subscribers.
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

File _writeSmallFile(Directory dir, String name, int length) {
  final file = File('${dir.path}/$name');
  file.writeAsBytesSync(List.generate(length, (i) => i % 256));
  return file;
}

Future<File> _createSparseOversizeFile(Directory dir, String name) async {
  final file = File('${dir.path}/$name');
  final raf = await file.open(mode: FileMode.write);
  // 100 MB cap (ChunkPlanner.maxTransferableSizeBytes) + 1 byte, created as
  // a sparse file via truncate — no actual bytes are written, so this is
  // fast regardless of the cap's size.
  await raf.truncate(100 * 1024 * 1024 + 1);
  await raf.close();
  return file;
}

void main() {
  group('SongSyncCoordinator (XFER-01, XFER-08, XFER-09, oversize edge case)',
      () {
    test(
        'syncSongToRoom sends every track to every connected participant, not just one',
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

      final sender = ChunkedFileSender(controller: master);
      final coordinator =
          SongSyncCoordinator(controller: master, sender: sender);
      addTearDown(coordinator.dispose);

      final discoveredForA = _subscribeDiscovery(visitorA);
      final discoveredForB = _subscribeDiscovery(visitorB);

      await master.createRoom();
      await masterSnapshotQueue.moveNext();
      final code = masterSnapshotQueue.current.room.code;

      final a = await _joinAndApprove(
          master, visitorA, masterSnapshotQueue, code, discoveredForA);
      final b = await _joinAndApprove(
          master, visitorB, masterSnapshotQueue, code, discoveredForB);

      final beginsSeenByA = <String>[];
      final beginsSeenByB = <String>[];
      _attachStubReceiver(visitorA, beginsSeenByA);
      _attachStubReceiver(visitorB, beginsSeenByB);

      final sourceDir = Directory.systemTemp.createTempSync('sync_fanout');
      addTearDown(() => sourceDir.deleteSync(recursive: true));
      final trackFile = _writeSmallFile(sourceDir, 'naipe.bin', 40);
      final playbackFile = _writeSmallFile(sourceDir, 'playback.bin', 40);

      final song = Song(
        id: 'song-fanout',
        name: 'Fanout Song',
        author: 'test',
        tracks: [
          SongTrack(
              id: 'track-naipe',
              filePath: trackFile.path,
              naipe: Naipe.soprano),
        ],
        playbackTrack: SongTrack(
          id: 'track-playback',
          filePath: playbackFile.path,
          naipe: Naipe.custom,
          isPlayback: true,
        ),
      );

      final result = await coordinator.syncSongToRoom(song);

      expect(result.isSuccess, isTrue);
      expect(a.id == b.id, isFalse);
      expect(
        beginsSeenByA.toSet(),
        equals({'track-naipe', 'track-playback'}),
      );
      expect(
        beginsSeenByB.toSet(),
        equals({'track-naipe', 'track-playback'}),
      );
    });

    test(
        'a track over the 100 MB cap is rejected before any chunk is sent (transfer.file-too-large)',
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

      final sender = ChunkedFileSender(controller: master);
      final coordinator =
          SongSyncCoordinator(controller: master, sender: sender);
      addTearDown(coordinator.dispose);

      final discoveredRoomFuture = _subscribeDiscovery(visitor);
      await master.createRoom();
      await masterSnapshotQueue.moveNext();
      final code = masterSnapshotQueue.current.room.code;
      await _joinAndApprove(
          master, visitor, masterSnapshotQueue, code, discoveredRoomFuture);

      var chunkDataMessagesSeen = 0;
      visitor.applicationMessages.listen((event) {
        if (RoomApplicationMessage.decode(event.$2) is ChunkDataMessage) {
          chunkDataMessagesSeen++;
        }
      });

      final sourceDir = Directory.systemTemp.createTempSync('sync_oversize');
      addTearDown(() => sourceDir.deleteSync(recursive: true));
      final oversizeFile =
          await _createSparseOversizeFile(sourceDir, 'huge.bin');

      final song = Song(
        id: 'song-oversize',
        name: 'Oversize Song',
        author: 'test',
        tracks: [
          SongTrack(
              id: 'track-huge',
              filePath: oversizeFile.path,
              naipe: Naipe.soprano),
        ],
      );

      final result = await coordinator.syncSongToRoom(song);

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) => expect(f.code, equals('transfer.file-too-large')),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(chunkDataMessagesSeen, equals(0));
    });

    test(
        'a second syncSongToRoom call queues behind the first instead of interleaving',
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

      final sender = ChunkedFileSender(controller: master);
      final coordinator =
          SongSyncCoordinator(controller: master, sender: sender);
      addTearDown(coordinator.dispose);

      final discoveredRoomFuture = _subscribeDiscovery(visitor);
      await master.createRoom();
      await masterSnapshotQueue.moveNext();
      final code = masterSnapshotQueue.current.room.code;
      await _joinAndApprove(
          master, visitor, masterSnapshotQueue, code, discoveredRoomFuture);

      // Song A's chunk ACKs are deliberately delayed, widening the window in
      // which an incorrectly-interleaving implementation would let song B's
      // TransferBegin arrive before song A's transfer is done.
      final eventOrder = <String>[];
      visitor.applicationMessages.listen((event) {
        final message = RoomApplicationMessage.decode(event.$2);
        if (message is TransferBeginMessage) {
          eventOrder.add('begin:${message.trackId}');
        }
        if (message is TransferCompleteMessage) {
          eventOrder.add('complete:${message.trackId}');
        }
      });
      _attachStubReceiver(
        visitor,
        <String>[],
        ackDelay: const Duration(milliseconds: 100),
      );

      final sourceDir = Directory.systemTemp.createTempSync('sync_queue');
      addTearDown(() => sourceDir.deleteSync(recursive: true));
      final fileA = _writeSmallFile(sourceDir, 'a.bin', 20);
      final fileB = _writeSmallFile(sourceDir, 'b.bin', 20);

      final songA = Song(
        id: 'song-a',
        name: 'Song A',
        author: 'test',
        tracks: [
          SongTrack(id: 'track-a', filePath: fileA.path, naipe: Naipe.soprano)
        ],
      );
      final songB = Song(
        id: 'song-b',
        name: 'Song B',
        author: 'test',
        tracks: [
          SongTrack(id: 'track-b', filePath: fileB.path, naipe: Naipe.soprano)
        ],
      );

      final resultAFuture = coordinator.syncSongToRoom(songA);
      final resultBFuture = coordinator.syncSongToRoom(songB);

      final resultA = await resultAFuture;
      final resultB = await resultBFuture;
      expect(resultA.isSuccess, isTrue);
      expect(resultB.isSuccess, isTrue);

      final completeAIndex = eventOrder.indexOf('complete:track-a');
      final beginBIndex = eventOrder.indexOf('begin:track-b');
      expect(completeAIndex, greaterThanOrEqualTo(0));
      expect(beginBIndex, greaterThanOrEqualTo(0));
      expect(
        completeAIndex,
        lessThan(beginBIndex),
        reason: 'song B must not start until song A has fully completed',
      );
    });

    test(
        'a visitor that IS connected to a real room is still rejected when it attempts to initiate a transfer (XFER-09: role-gate rejection, not a no-op)',
        () async {
      // The original version of this test drove a visitor controller that
      // never created/joined a room, so `connectedParticipants` was
      // trivially empty and `syncSongToRoom` "succeeded" by having nothing
      // to do — that proves "nothing to send to", not an active role-gate
      // rejection. This version connects the visitor to a real master room
      // (full join + approve + handshake, same as every other test in this
      // file) and then has that connected visitor directly attempt to send
      // a track via its own `ChunkedFileSender`, exercising the actual
      // enforcement mechanism: a visitor's `RoomSessionController` never
      // runs `createRoom()`, so it never has a `_stateMachine`, so every
      // `sendEnvelopeTo` call `ChunkedFileSender.sendTrack` makes (to
      // deliver `TransferBeginMessage`/`ChunkDataMessage`) fails with
      // `NotFoundFailure(code: 'session.participant-not-found')` and never
      // touches the transport — `sendTrack` itself doesn't check that
      // per-send result, so it surfaces as a retry-exhaustion
      // `NetworkFailure(code: 'transfer.chunk-delivery-failed')` once no
      // ACK ever arrives, but the master-side proof is sharper: nothing the
      // visitor sends ever reaches `master.applicationMessages`, because it
      // never left the visitor's controller in the first place.
      //
      // (A `SongSyncCoordinator` built on the visitor's own controller
      // would still be a no-op for a different, structural reason: a
      // visitor's `snapshots` stream never emits at all, because
      // `_emitSnapshot()` short-circuits when `_stateMachine` is null — so
      // routing this through the coordinator would silently reproduce the
      // same vacuous "nothing to send to" shape this fix is removing.
      // Calling `sendTrack` directly is what actually exercises the gate.)
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

      // Full join/approve/handshake — the visitor really is `connected`,
      // not just instantiated.
      await _joinAndApprove(
          master, visitor, masterSnapshotQueue, code, discoveredRoomFuture);

      // Short timeouts/one attempt: the rejection happens instantly inside
      // `sendEnvelopeTo` (no `_stateMachine`), so there is nothing to
      // actually wait out — these just bound how long the test spends
      // watching `sendTrack` run through its (doomed) retry loop.
      final sender = ChunkedFileSender(
        controller: visitor,
        maxAttemptsPerChunk: 1,
        ackTimeout: const Duration(milliseconds: 100),
        resumeProbeTimeout: const Duration(milliseconds: 50),
      );

      final masterReceived = <RoomApplicationMessage>[];
      master.applicationMessages.listen(
        (event) => masterReceived.add(RoomApplicationMessage.decode(event.$2)),
      );

      final sourceDir =
          Directory.systemTemp.createTempSync('sync_visitor_connected');
      addTearDown(() => sourceDir.deleteSync(recursive: true));
      final file = _writeSmallFile(sourceDir, 'track.bin', 10);
      final track = SongTrack(
        id: 'track-x',
        filePath: file.path,
        naipe: Naipe.soprano,
      );

      final result = await sender.sendTrack(
        songId: 'song-visitor-initiated',
        track: track,
        to: const ParticipantId('master-device'),
      );

      expect(result.isFailure, isTrue,
          reason: 'a connected visitor must still be rejected when it '
              'tries to initiate a transfer, not merely have nothing to '
              'send to');
      result.when(
        success: (_) => fail('expected a failure, got success'),
        failure: (f) =>
            expect(f.code, equals('transfer.chunk-delivery-failed')),
      );
      expect(masterReceived, isEmpty,
          reason: 'the real role-gate proof: nothing the rejected visitor '
              'attempted to send ever reached the master at all — this is '
              'an active structural rejection, not "nothing to send to"');
    });
  });
}
