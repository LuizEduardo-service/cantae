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
        ChunkAckMessage(trackId: message.trackId, chunkIndex: message.chunkIndex)
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
          SongTrack(id: 'track-naipe', filePath: trackFile.path, naipe: Naipe.soprano),
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
      final oversizeFile = await _createSparseOversizeFile(sourceDir, 'huge.bin');

      final song = Song(
        id: 'song-oversize',
        name: 'Oversize Song',
        author: 'test',
        tracks: [
          SongTrack(id: 'track-huge', filePath: oversizeFile.path, naipe: Naipe.soprano),
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
        tracks: [SongTrack(id: 'track-a', filePath: fileA.path, naipe: Naipe.soprano)],
      );
      final songB = Song(
        id: 'song-b',
        name: 'Song B',
        author: 'test',
        tracks: [SongTrack(id: 'track-b', filePath: fileB.path, naipe: Naipe.soprano)],
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
        'a coordinator built on a visitor-role controller (no state machine) sends nothing (XFER-09: cannot initiate a transfer)',
        () async {
      final bus = StreamController<DiscoveredRoom>.broadcast();
      final visitorOnly = RoomSessionController(
        transport: TcpSessionTransport(),
        discovery: _FakeRoomDiscovery(bus),
        handshakeService: HandshakeService(),
        selfDeviceId: const DeviceId('visitor-only-device'),
      );
      addTearDown(() {
        visitorOnly.dispose();
        bus.close();
      });

      final sender = ChunkedFileSender(controller: visitorOnly);
      final coordinator =
          SongSyncCoordinator(controller: visitorOnly, sender: sender);
      addTearDown(coordinator.dispose);

      final sourceDir = Directory.systemTemp.createTempSync('sync_visitor_only');
      addTearDown(() => sourceDir.deleteSync(recursive: true));
      final file = _writeSmallFile(sourceDir, 'track.bin', 10);
      final song = Song(
        id: 'song-visitor-only',
        name: 'Visitor Only Song',
        author: 'test',
        tracks: [SongTrack(id: 'track-x', filePath: file.path, naipe: Naipe.soprano)],
      );

      // No room was ever created on this controller, so it never has a
      // connected-participant snapshot to fan out to — the structural
      // enforcement of "a visitor device cannot initiate a transfer".
      final result = await coordinator.syncSongToRoom(song);
      expect(result.isSuccess, isTrue, reason: 'no participants to send to is a trivial success, not an error');
    });
  });
}
