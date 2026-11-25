import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/data/playback/playback_command_broadcaster.dart';
import 'package:cantae/data/playback/playback_command_handler.dart';
import 'package:cantae/data/session/room_application_message.dart';
import 'package:cantae/data/session/room_session_controller.dart';
import 'package:cantae/domain/audio/audio_playback_engine.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/entities/song_track.dart';
import 'package:cantae/domain/playback/room_playback_snapshot.dart';
import 'package:cantae/domain/session/handshake_service.dart';
import 'package:cantae/domain/session/ids.dart';
import 'package:cantae/domain/session/participant_session.dart';
import 'package:cantae/domain/session/room_discovery.dart';
import 'package:cantae/domain/session/room_session_snapshot.dart';
import 'package:cantae/infrastructure/network/tcp_session_transport.dart';

/// Minimal fake `AudioPlaybackEngine` (the real engine is plugin-backed and
/// out of scope for `flutter test` per the Test Coverage Matrix). Records
/// every call so tests can assert on what the handler actually invoked.
class FakeAudioPlaybackEngine implements AudioPlaybackEngine {
  final List<DateTime> playAtCalls = [];
  final List<Song> loadSongCalls = [];
  int pauseCalls = 0;
  int stopCalls = 0;
  final List<int> seekAllToCalls = [];

  @override
  Future<void> loadSong(Song song) async {
    loadSongCalls.add(song);
  }

  @override
  Future<void> playAt(DateTime scheduledStart) async {
    playAtCalls.add(scheduledStart);
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> seekAllTo(int timelineMs) async {
    seekAllToCalls.add(timelineMs);
  }

  @override
  Future<void> setTrackMuted(String trackId, bool muted) async {}

  @override
  Future<void> setTrackSolo(String trackId, bool solo) async {}

  @override
  Future<void> setTrackVolume(String trackId, double volume) async {}

  @override
  Future<void> addTrack(SongTrack track, {bool exemptFromSolo = false}) async {}

  @override
  Future<void> setDucked(bool ducked) async {}

  @override
  Future<void> removeTrack(String trackId) async {}

  @override
  Future<void> setTrackStartDelayMs(String trackId, int startDelayMs) async {}

  @override
  int? get durationMs => null;

  @override
  Stream<int> get positionMs => const Stream.empty();
}

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

/// playAt that signals when it is called and finishes only when released.
class _GatedEngine extends FakeAudioPlaybackEngine {
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> playAt(DateTime scheduledStart) async {
    playAtCalls.add(scheduledStart);
    started.complete();
    await release.future;
  }
}

void main() {
  group('PlaybackCommandHandler (SYNC-01, SYNC-03, SYNC-05, SYNC-06, SYNC-08)',
      () {
    // Regression (flaky-tests): dispose() closed the snapshot stream but
    // left the scheduled Timer running. A disposed handler still called
    // engine.playAt at the scheduled time, and a playAt still starting at
    // dispose emitted into the closed stream ("Cannot add new events after
    // calling close").
    test('disposing before the scheduled time never calls the engine',
        () async {
      final engine = FakeAudioPlaybackEngine();
      final handler = PlaybackCommandHandler(engine: engine);
      handler.handleApplicationMessage(PlayCommandMessage(
        songId: 'song-1',
        masterSendEpochMs: DateTime.now()
            .add(const Duration(milliseconds: 50))
            .millisecondsSinceEpoch,
      ));

      handler.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(engine.playAtCalls, isEmpty);
    });

    test('disposing while the engine is starting emits nothing afterwards',
        () async {
      final engine = _GatedEngine();
      final handler = PlaybackCommandHandler(engine: engine);
      final phases = <PlaybackPhase>[];
      handler.snapshots.listen((s) => phases.add(s.phase));
      handler.handleApplicationMessage(PlayCommandMessage(
        songId: 'song-1',
        masterSendEpochMs: DateTime.now().millisecondsSinceEpoch,
      ));
      await engine.started.future.timeout(const Duration(seconds: 2));

      handler.dispose();
      engine.release.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(phases, isNot(contains(PlaybackPhase.playing)));
    });

    test(
        'snapshots transition idle -> scheduled -> playing on a PlayCommandMessage, calling the fake engine playAt at the scheduled epoch',
        () async {
      final engine = FakeAudioPlaybackEngine();
      final handler = PlaybackCommandHandler(engine: engine);
      addTearDown(handler.dispose);

      final phases = <PlaybackPhase>[];
      handler.snapshots.listen((s) => phases.add(s.phase));

      final targetEpoch = DateTime.now()
          .add(const Duration(milliseconds: 50))
          .millisecondsSinceEpoch;
      handler.handleApplicationMessage(
        PlayCommandMessage(songId: 'song-1', masterSendEpochMs: targetEpoch),
      );

      expect(handler.current.phase, equals(PlaybackPhase.scheduled));
      expect(engine.playAtCalls, isEmpty);

      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while (engine.playAtCalls.isEmpty && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(engine.playAtCalls, hasLength(1));
      expect(
        engine.playAtCalls.single.millisecondsSinceEpoch,
        equals(targetEpoch),
      );
      expect(handler.current.phase, equals(PlaybackPhase.playing));
      expect(phases,
          containsAllInOrder([PlaybackPhase.scheduled, PlaybackPhase.playing]));
    });

    test(
        'a device that learns the room is already playing enters waiting and does not call the engine until the next PlayCommand',
        () async {
      final engine = FakeAudioPlaybackEngine();
      final handler = PlaybackCommandHandler(engine: engine);
      addTearDown(handler.dispose);

      handler.handleApplicationMessage(
        const PlaybackSnapshotMessage(songId: 'song-1', state: 'playing'),
      );

      expect(handler.current.phase, equals(PlaybackPhase.waiting));
      expect(engine.playAtCalls, isEmpty);
      expect(engine.loadSongCalls, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(engine.playAtCalls, isEmpty,
          reason: 'waiting must not call the engine on its own');

      final targetEpoch = DateTime.now().millisecondsSinceEpoch;
      handler.handleApplicationMessage(
        PlayCommandMessage(songId: 'song-1', masterSendEpochMs: targetEpoch),
      );

      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while (engine.playAtCalls.isEmpty && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(engine.playAtCalls, hasLength(1));
      expect(handler.current.phase, equals(PlaybackPhase.playing));
    });

    test(
        'handleApplicationMessage processes a message handed to it directly, with no independent role-checking code path (trust-the-gate design decision)',
        () async {
      // No RoomSessionController at all — the handler is driven directly,
      // bypassing any envelope/role verification entirely. If the handler
      // had its own role check, this message (carrying no role/sender
      // information at all) would have nothing to validate against and
      // would have to either reject it or ignore role — it processes it,
      // proving there is no such independent gate inside this class.
      final engine = FakeAudioPlaybackEngine();
      final handler = PlaybackCommandHandler(engine: engine);
      addTearDown(handler.dispose);

      final targetEpoch = DateTime.now().millisecondsSinceEpoch;
      handler.handleApplicationMessage(
        PlayCommandMessage(songId: 'song-x', masterSendEpochMs: targetEpoch),
      );

      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while (engine.playAtCalls.isEmpty && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(engine.playAtCalls, hasLength(1));
    });

    test(
        'E2E: a real PlaybackCommandBroadcaster.play() drives a PlaybackCommandHandler + fake engine on each of 3 real loopback devices, with epochs within the latency-estimate spread',
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

      final broadcaster = PlaybackCommandBroadcaster(controller: master);
      addTearDown(broadcaster.dispose);

      await master.createRoom();
      await masterSnapshotQueue.moveNext();
      final code = masterSnapshotQueue.current.room.code;

      await _joinAndApprove(
          master, visitorA, masterSnapshotQueue, code, discoveredForA);
      await _joinAndApprove(
          master, visitorB, masterSnapshotQueue, code, discoveredForB);

      final engineMaster = FakeAudioPlaybackEngine();
      final engineA = FakeAudioPlaybackEngine();
      final engineB = FakeAudioPlaybackEngine();

      final handlerA =
          PlaybackCommandHandler(engine: engineA, controller: visitorA);
      final handlerB =
          PlaybackCommandHandler(engine: engineB, controller: visitorB);
      addTearDown(() {
        handlerA.dispose();
        handlerB.dispose();
      });
      // Master's own loopback handler (design.md: "every device including
      // the master's own loopback") listens on the master's own
      // applicationMessages — but PlaybackCommandBroadcaster only sends to
      // *participants*, not to itself, so engineMaster is unused here; kept
      // to document that a master-local handler is a separate concern this
      // test doesn't drive.
      expect(engineMaster.playAtCalls, isEmpty);

      await broadcaster.play('song-sync');

      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while ((engineA.playAtCalls.isEmpty || engineB.playAtCalls.isEmpty) &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      expect(engineA.playAtCalls, hasLength(1));
      expect(engineB.playAtCalls, hasLength(1));

      final epochA = engineA.playAtCalls.single.millisecondsSinceEpoch;
      final epochB = engineB.playAtCalls.single.millisecondsSinceEpoch;
      // On a real loopback LAN, both participants' estimated one-way delay
      // is sub-100ms; their scheduled epochs must land within that spread
      // of each other.
      expect((epochA - epochB).abs(), lessThan(200));
    });

    test(
        'E2E (SYNC-06): a participant that joins AFTER the master already called play() receives a production-sent PlaybackSnapshotMessage and enters waiting, without the test driving handleApplicationMessage directly',
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
      // visitorB subscribes to discovery now too, even though it only joins
      // later: the fake discovery bus is a plain broadcast stream that
      // never replays past events, and `createRoom()` advertises exactly
      // once — a subscription started after that call would never see it.
      final discoveredForB = _subscribeDiscovery(visitorB);

      final broadcaster = PlaybackCommandBroadcaster(controller: master);
      addTearDown(broadcaster.dispose);

      await master.createRoom();
      await masterSnapshotQueue.moveNext();
      final code = masterSnapshotQueue.current.room.code;

      // Only visitorA is connected when play() fires.
      await _joinAndApprove(
          master, visitorA, masterSnapshotQueue, code, discoveredForA);

      final engineA = FakeAudioPlaybackEngine();
      final handlerA =
          PlaybackCommandHandler(engine: engineA, controller: visitorA);
      addTearDown(handlerA.dispose);

      await broadcaster.play('song-late');

      final aPlayedDeadline = DateTime.now().add(const Duration(seconds: 3));
      while (engineA.playAtCalls.isEmpty &&
          DateTime.now().isBefore(aPlayedDeadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(engineA.playAtCalls, hasLength(1),
          reason: 'sanity check: the room really is playing before B joins');

      // visitorB requests to join only now, strictly after the play
      // command above — this is the late-join scenario SYNC-06 covers. Its
      // handler is wired before the join completes so it is listening when
      // the master's PlaybackSnapshotMessage (sent automatically by
      // production code on the new-connection snapshot event, not by this
      // test) arrives.
      final engineB = FakeAudioPlaybackEngine();
      final handlerB =
          PlaybackCommandHandler(engine: engineB, controller: visitorB);
      addTearDown(handlerB.dispose);

      await _joinAndApprove(
          master, visitorB, masterSnapshotQueue, code, discoveredForB);

      final waitingDeadline = DateTime.now().add(const Duration(seconds: 3));
      while (handlerB.current.phase != PlaybackPhase.waiting &&
          DateTime.now().isBefore(waitingDeadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      expect(handlerB.current.phase, equals(PlaybackPhase.waiting),
          reason: 'B must learn the room is already playing and wait, '
              'via production wiring — this test never calls '
              'handleApplicationMessage itself');
      expect(handlerB.current.activeSongId, equals('song-late'));
      expect(engineB.playAtCalls, isEmpty,
          reason: 'a late joiner must not cut into mid-stream audio');
    });
  });
}
