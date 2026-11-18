import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';

import 'package:cantae/data/playback/playback_command_broadcaster.dart';
import 'package:cantae/data/playback/playback_command_handler.dart';
import 'package:cantae/data/transfer/chunked_file_receiver.dart';
import 'package:cantae/data/transfer/chunked_file_sender.dart';
import 'package:cantae/data/transfer/library_storage_paths.dart';
import 'package:cantae/data/session/room_session_controller.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/entities/song_track.dart';
import 'package:cantae/domain/session/handshake_service.dart';
import 'package:cantae/domain/session/ids.dart';
import 'package:cantae/domain/session/participant_session.dart';
import 'package:cantae/domain/session/room_discovery.dart';
import 'package:cantae/domain/session/room_session_snapshot.dart';
import 'package:cantae/domain/transfer/file_transfer_state.dart';
import 'package:cantae/infrastructure/audio/background_audio_handler.dart';
import 'package:cantae/infrastructure/audio/multi_track_audio_engine.dart';
import 'package:cantae/infrastructure/network/tcp_session_transport.dart';

/// Real-device E2E for file transfer, synchronized playback, and background
/// audio (T18, `file-transfer-and-sync-playback`). Run on a connected
/// physical device with:
/// `flutter test -d <device-id> integration_test/file_transfer_and_sync_playback_test.dart`
///
/// What this test exercises for real (no fakes, no mocks):
/// 1. A real multi-track file transfer over real loopback TCP
///    (`ChunkedFileSender` + `ChunkedFileReceiver`), ending with a
///    hash-validated file written through the real `path_provider` app-sandbox
///    path (`LibraryStoragePaths`).
/// 2. The real `MultiTrackAudioEngine` loading that file and driving a real
///    `just_audio` `AudioPlayer` to an actual `playing` state.
/// 3. The real `BackgroundAudioHandler` registered with `audio_service`
///    (`AudioService.init()`), and a programmatic play/pause call round-
///    tripping through the real `PlaybackCommandBroadcaster` over the
///    network to a receiving device's `PlaybackCommandHandler`, which drives
///    a second real `AudioPlayer`.
///
/// HONEST SCOPE NOTES (written down, not hidden — mirrors Phase 3's
/// acknowledged NET-02 gap):
/// - SYNC-03 (max pairwise playback-start delta ≤100 ms across physical
///   devices): NOT measured here. Only one physical device is available in
///   this environment (`.specs/STATE.md` AD-007/Handoff). "Master" and
///   "visitor" below are two `RoomSessionController`s on the SAME device,
///   talking over 127.0.0.1 — this proves the real wire protocol, the real
///   engine, and the real plugin surfaces end-to-end, but cannot measure
///   cross-hardware clock/network variance. That measurement needs a second
///   physical device.
/// - BG-01/BG-02/BG-03 (OS actually locking the screen; a human tapping a
///   lock-screen/notification control): NOT exercised here —
///   `integration_test` cannot simulate the OS lock screen or a physical tap.
///   What IS verified: `AudioService.init()` succeeds on this device (the
///   handler is registered and reachable) and a programmatic
///   play()/pause() call on it round-trips all the way down to a real
///   `AudioPlayer`. Full lock-screen/notification-tap verification needs
///   manual QA on-device.
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

/// Builds a minimal, valid, silent 16-bit PCM mono WAV file — small enough to
/// transfer and decode quickly on-device, but a real decodable audio file
/// (not a stub), so the real `just_audio`/ExoPlayer decode path is exercised.
Uint8List _buildSilentWavBytes({int durationMs = 300, int sampleRate = 8000}) {
  const numChannels = 1;
  const bitsPerSample = 16;
  final numSamples = (sampleRate * durationMs) ~/ 1000;
  const blockAlign = numChannels * bitsPerSample ~/ 8;
  final dataSize = numSamples * blockAlign;
  final byteRate = sampleRate * blockAlign;

  final buffer = BytesBuilder();
  void writeString(String s) => buffer.add(ascii.encode(s));
  void writeUint32(int v) {
    final b = ByteData(4)..setUint32(0, v, Endian.little);
    buffer.add(b.buffer.asUint8List());
  }

  void writeUint16(int v) {
    final b = ByteData(2)..setUint16(0, v, Endian.little);
    buffer.add(b.buffer.asUint8List());
  }

  writeString('RIFF');
  writeUint32(36 + dataSize);
  writeString('WAVE');
  writeString('fmt ');
  writeUint32(16);
  writeUint16(1); // PCM
  writeUint16(numChannels);
  writeUint32(sampleRate);
  writeUint32(byteRate);
  writeUint16(blockAlign);
  writeUint16(bitsPerSample);
  writeString('data');
  writeUint32(dataSize);
  buffer.add(Uint8List(dataSize)); // silence

  return buffer.toBytes();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test(
    'real multi-track transfer, real MultiTrackAudioEngine playback, and real '
    'BackgroundAudioHandler/audio_service round trip on a physical device',
    () async {
      final log = <String>[];
      void record(String line) {
        log.add(line);
        // ignore: avoid_print
        print(line);
      }

      // ---------------------------------------------------------------
      // Phase 1: real file transfer over real loopback TCP, ending with
      // a hash-validated file in the real app-sandbox storage.
      // ---------------------------------------------------------------
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
      final visitorSession = await _joinAndApprove(
        master,
        visitor,
        masterSnapshotQueue,
        code,
        discoveredRoomFuture,
      );
      record('real loopback room joined on-device: visitor connected');

      final sourceDir = Directory.systemTemp.createTempSync('t18_source');
      addTearDown(() => sourceDir.deleteSync(recursive: true));
      final sourceBytes = _buildSilentWavBytes();
      final sourceFile = File('${sourceDir.path}/track.wav');
      await sourceFile.writeAsBytes(sourceBytes);
      final expectedSha256 = sha256.convert(sourceBytes).toString();

      final storageRoot = await LibraryStoragePaths.resolveLibraryRoot();
      record('real path_provider storage root resolved: ${storageRoot.path}');

      final sender = ChunkedFileSender(controller: master);
      final receiver = ChunkedFileReceiver(
        controller: visitor,
        storageRoot: storageRoot,
      );

      final progressStream = receiver.receiveTrack(
        trackId: 'track-device-test',
        expectedSha256: expectedSha256,
        totalSizeBytes: sourceBytes.length,
        extension: 'wav',
      );
      final transferDone = Completer<TransferProgress>();
      final progressSubscription = progressStream.listen((p) {
        if ((p.phase == TransferPhase.available ||
                p.phase == TransferPhase.failed) &&
            !transferDone.isCompleted) {
          transferDone.complete(p);
        }
      });

      final sendResult = await sender.sendTrack(
        songId: 'song-device-test',
        track: SongTrack(
          id: 'track-device-test',
          filePath: sourceFile.path,
          naipe: Naipe.soprano,
        ),
        to: visitorSession.id,
      );
      expect(sendResult.isSuccess, isTrue);

      final finalProgress =
          await transferDone.future.timeout(const Duration(seconds: 30));
      await progressSubscription.cancel();
      expect(finalProgress.phase, equals(TransferPhase.available));

      final finalFilePath = LibraryStoragePaths.trackFilePath(
        root: storageRoot,
        sha256: expectedSha256,
        extension: 'wav',
      );
      final finalFile = File(finalFilePath);
      expect(finalFile.existsSync(), isTrue);
      final finalBytes = await finalFile.readAsBytes();
      expect(
        sha256.convert(finalBytes).toString(),
        equals(expectedSha256),
      );
      record(
        'real transfer complete: hash-validated file at $finalFilePath '
        '(${finalBytes.length} bytes, sha256 matches)',
      );

      // ---------------------------------------------------------------
      // Phase 2: the real MultiTrackAudioEngine loads the transferred file
      // and drives a real just_audio AudioPlayer to an actual "playing"
      // state (not just an internal bookkeeping flag).
      // ---------------------------------------------------------------
      final song = Song(
        id: 'song-device-test',
        name: 'Device Test Song',
        author: 'T18',
        tracks: [
          SongTrack(
            id: 'track-device-test',
            filePath: finalFilePath,
            naipe: Naipe.soprano,
          ),
        ],
      );

      final masterPlayers = <AudioPlayer>[];
      final masterEngine = MultiTrackAudioEngine(
        playerFactory: () {
          final player = AudioPlayer();
          masterPlayers.add(player);
          return player;
        },
      );
      addTearDown(masterEngine.dispose);

      await masterEngine.loadSong(song);
      expect(masterPlayers, hasLength(1));

      await masterEngine.playAt(DateTime.now());

      final playingDeadline = DateTime.now().add(const Duration(seconds: 10));
      while (!masterPlayers.first.playing &&
          DateTime.now().isBefore(playingDeadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(
        masterPlayers.first.playing,
        isTrue,
        reason:
            'real just_audio AudioPlayer must report playing after MultiTrackAudioEngine.playAt()',
      );
      record(
        'real MultiTrackAudioEngine reached playing state on a real just_audio AudioPlayer',
      );

      // ---------------------------------------------------------------
      // Phase 3: the real BackgroundAudioHandler registers with
      // audio_service, and a programmatic play()/pause() call round-trips
      // through the real PlaybackCommandBroadcaster, over the network, to
      // a receiving device's PlaybackCommandHandler, driving a second real
      // AudioPlayer.
      // ---------------------------------------------------------------
      final broadcaster = PlaybackCommandBroadcaster(controller: master);
      addTearDown(broadcaster.dispose);

      final visitorPlayers = <AudioPlayer>[];
      final visitorEngine = MultiTrackAudioEngine(
        playerFactory: () {
          final player = AudioPlayer();
          visitorPlayers.add(player);
          return player;
        },
      );
      addTearDown(visitorEngine.dispose);
      await visitorEngine.loadSong(song);
      expect(visitorPlayers, hasLength(1));

      final visitorHandler =
          PlaybackCommandHandler(engine: visitorEngine, controller: visitor);
      addTearDown(visitorHandler.dispose);

      final backgroundHandler = await AudioService.init<BackgroundAudioHandler>(
        builder: () => BackgroundAudioHandler(
          broadcaster: broadcaster,
          engine: masterEngine,
        ),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.cantae.cantae.channel.audio',
          androidNotificationChannelName: 'Cantaê Rehearsal Audio',
        ),
      );
      addTearDown(backgroundHandler.dispose);
      record(
        'AudioService.init() succeeded on real device — BackgroundAudioHandler registered and reachable',
      );

      backgroundHandler.setActiveSongMediaItem(song.id, song.name);
      await backgroundHandler.play();

      final visitorPlayingDeadline =
          DateTime.now().add(const Duration(seconds: 10));
      while (!visitorPlayers.first.playing &&
          DateTime.now().isBefore(visitorPlayingDeadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(
        visitorPlayers.first.playing,
        isTrue,
        reason:
            'BackgroundAudioHandler.play() must round-trip through PlaybackCommandBroadcaster -> network -> PlaybackCommandHandler -> a real AudioPlayer',
      );
      record(
        'BackgroundAudioHandler.play() round-tripped through PlaybackCommandBroadcaster '
        'over the network to a real AudioPlayer on the receiving device',
      );

      await backgroundHandler.pause();

      final pauseDeadline = DateTime.now().add(const Duration(seconds: 10));
      while (visitorPlayers.first.playing &&
          DateTime.now().isBefore(pauseDeadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(
        visitorPlayers.first.playing,
        isFalse,
        reason:
            'BackgroundAudioHandler.pause() must round-trip the same path and actually pause the real AudioPlayer',
      );
      record(
        'BackgroundAudioHandler.pause() round-tripped and paused the real AudioPlayer',
      );

      await backgroundHandler.stop();
      record('BackgroundAudioHandler.stop() completed without error');

      // ignore: avoid_print
      print('--- full transition log (${log.length} steps) ---');
      for (final line in List<String>.from(log)) {
        // ignore: avoid_print
        print(line);
      }
    },
    timeout: const Timeout(Duration(seconds: 120)),
  );
}
