import 'dart:async';

import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/entities/song_track.dart';
import 'package:cantae/infrastructure/audio/multi_track_audio_engine.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_just_audio_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeJustAudioPlatform fakePlatform;
  late MultiTrackAudioEngine engine;

  AudioPlayer newTestPlayer() => AudioPlayer(
        handleAudioSessionActivation: false,
        handleInterruptions: false,
      );

  setUp(() {
    fakePlatform = FakeJustAudioPlatform();
    JustAudioPlatform.instance = fakePlatform;
    engine = MultiTrackAudioEngine(playerFactory: newTestPlayer);
  });

  Song songWith({
    required String sopranoId,
    required String contraltoId,
    int sopranoDelayMs = 0,
    int contraltoDelayMs = 0,
  }) =>
      Song(
        id: 'song-1',
        name: 'Ave Maria',
        author: 'Caccini',
        tracks: [
          SongTrack(
            id: sopranoId,
            filePath: '/tmp/soprano.mp3',
            naipe: Naipe.soprano,
            startDelayMs: sopranoDelayMs,
          ),
          SongTrack(
            id: contraltoId,
            filePath: '/tmp/contralto.mp3',
            naipe: Naipe.contralto,
            startDelayMs: contraltoDelayMs,
          ),
        ],
      );

  group('setTrackMuted', () {
    test('mutes the given track to volume 0, leaves others unchanged',
        () async {
      await engine.loadSong(songWith(sopranoId: 's', contraltoId: 'c'));
      final sopranoPlatform = fakePlatform.created[0];
      final contraltoPlatform = fakePlatform.created[1];

      await engine.setTrackMuted('s', true);

      expect(sopranoPlatform.setVolumeCalls.last.volume, 0.0);
      expect(contraltoPlatform.setVolumeCalls.last.volume, 1.0);
    });

    test('unmuting restores the track\'s base gain', () async {
      await engine.loadSong(songWith(sopranoId: 's', contraltoId: 'c'));
      final sopranoPlatform = fakePlatform.created[0];

      await engine.setTrackMuted('s', true);
      await engine.setTrackMuted('s', false);

      expect(sopranoPlatform.setVolumeCalls.last.volume, 1.0);
    });
  });

  group('setTrackSolo', () {
    test('solos the given track, silencing every other loaded track', () async {
      await engine.loadSong(songWith(sopranoId: 's', contraltoId: 'c'));
      final sopranoPlatform = fakePlatform.created[0];
      final contraltoPlatform = fakePlatform.created[1];

      await engine.setTrackSolo('s', true);

      expect(sopranoPlatform.setVolumeCalls.last.volume, 1.0);
      expect(contraltoPlatform.setVolumeCalls.last.volume, 0.0);
    });

    test('activating solo on a second track clears the first track\'s solo',
        () async {
      await engine.loadSong(songWith(sopranoId: 's', contraltoId: 'c'));
      final sopranoPlatform = fakePlatform.created[0];
      final contraltoPlatform = fakePlatform.created[1];

      await engine.setTrackSolo('s', true);
      await engine.setTrackSolo('c', true);

      expect(sopranoPlatform.setVolumeCalls.last.volume, 0.0);
      expect(contraltoPlatform.setVolumeCalls.last.volume, 1.0);
    });

    test('clearing solo restores each track\'s volume per its own mute state',
        () async {
      await engine.loadSong(songWith(sopranoId: 's', contraltoId: 'c'));
      final sopranoPlatform = fakePlatform.created[0];
      final contraltoPlatform = fakePlatform.created[1];

      await engine.setTrackMuted('c', true);
      await engine.setTrackSolo('s', true);
      await engine.setTrackSolo('s', false);

      expect(sopranoPlatform.setVolumeCalls.last.volume, 1.0);
      expect(contraltoPlatform.setVolumeCalls.last.volume, 0.0);
    });
  });

  group('setTrackVolume', () {
    test('applies the volume to that track only', () async {
      await engine.loadSong(songWith(sopranoId: 's', contraltoId: 'c'));
      final sopranoPlatform = fakePlatform.created[0];
      final contraltoPlatform = fakePlatform.created[1];

      await engine.setTrackVolume('s', 0.3);

      expect(sopranoPlatform.setVolumeCalls.last.volume, closeTo(0.3, 1e-9));
      expect(contraltoPlatform.setVolumeCalls.last.volume, 1.0);
    });

    test('clamps values above 1 and below 0', () async {
      await engine.loadSong(songWith(sopranoId: 's', contraltoId: 'c'));
      final sopranoPlatform = fakePlatform.created[0];

      await engine.setTrackVolume('s', 1.7);
      expect(sopranoPlatform.setVolumeCalls.last.volume, 1.0);

      await engine.setTrackVolume('s', -0.2);
      expect(sopranoPlatform.setVolumeCalls.last.volume, 0.0);
    });

    test('a muted track stays silent, and unmuting restores its volume',
        () async {
      await engine.loadSong(songWith(sopranoId: 's', contraltoId: 'c'));
      final sopranoPlatform = fakePlatform.created[0];

      await engine.setTrackMuted('s', true);
      await engine.setTrackVolume('s', 0.4);
      expect(sopranoPlatform.setVolumeCalls.last.volume, 0.0);

      await engine.setTrackMuted('s', false);
      expect(sopranoPlatform.setVolumeCalls.last.volume, closeTo(0.4, 1e-9));
    });

    test('while another track is soloed, the track stays silent', () async {
      await engine.loadSong(songWith(sopranoId: 's', contraltoId: 'c'));
      final contraltoPlatform = fakePlatform.created[1];

      await engine.setTrackSolo('s', true);
      await engine.setTrackVolume('c', 0.5);

      expect(contraltoPlatform.setVolumeCalls.last.volume, 0.0);
    });

    test('the soloed track plays at its own volume', () async {
      await engine.loadSong(songWith(sopranoId: 's', contraltoId: 'c'));
      final sopranoPlatform = fakePlatform.created[0];

      await engine.setTrackVolume('s', 0.6);
      await engine.setTrackSolo('s', true);

      expect(sopranoPlatform.setVolumeCalls.last.volume, closeTo(0.6, 1e-9));
    });

    test('loading a song again resets every volume to 100 %', () async {
      await engine.loadSong(songWith(sopranoId: 's', contraltoId: 'c'));
      await engine.setTrackVolume('s', 0.2);

      await engine.loadSong(songWith(sopranoId: 's', contraltoId: 'c'));
      await engine.setTrackMuted('s', false);

      final reloadedSoprano = fakePlatform.created[2];
      expect(reloadedSoprano.setVolumeCalls.last.volume, 1.0);
    });
  });

  group('addTrack / removeTrack', () {
    const click = SongTrack(
      id: 'metronome',
      filePath: '/tmp/metronome.wav',
      naipe: Naipe.custom,
    );

    test('adds one more player at full volume without reloading the others',
        () async {
      await engine.loadSong(songWith(sopranoId: 's', contraltoId: 'c'));

      await engine.addTrack(click);

      expect(fakePlatform.created, hasLength(3));
      expect(fakePlatform.created[0].loadCalls, hasLength(1));
      expect(fakePlatform.created[1].loadCalls, hasLength(1));
      expect(fakePlatform.created[2].setVolumeCalls.last.volume, 1.0);
    });

    test('the added track follows seekAllTo, volume and mute', () async {
      await engine.loadSong(songWith(sopranoId: 's', contraltoId: 'c'));
      await engine.addTrack(click);
      final clickPlatform = fakePlatform.created[2];

      await engine.seekAllTo(41000);
      expect(clickPlatform.seekCalls.last.position,
          const Duration(milliseconds: 41000));

      await engine.setTrackVolume('metronome', 0.4);
      expect(clickPlatform.setVolumeCalls.last.volume, closeTo(0.4, 1e-9));

      await engine.setTrackMuted('metronome', true);
      expect(clickPlatform.setVolumeCalls.last.volume, 0.0);
    });

    test('a solo-exempt track keeps sounding while a voice is soloed',
        () async {
      await engine.loadSong(songWith(sopranoId: 's', contraltoId: 'c'));
      await engine.addTrack(click, exemptFromSolo: true);
      final clickPlatform = fakePlatform.created[2];

      await engine.setTrackSolo('s', true);

      expect(clickPlatform.setVolumeCalls.last.volume, 1.0);
      expect(fakePlatform.created[1].setVolumeCalls.last.volume, 0.0);
    });

    test('removeTrack disposes only that player', () async {
      await engine.loadSong(songWith(sopranoId: 's', contraltoId: 'c'));
      await engine.addTrack(click);

      await engine.removeTrack('metronome');

      expect(fakePlatform.created[2].disposed, isTrue);
      expect(fakePlatform.created[0].disposed, isFalse);
      expect(fakePlatform.created[1].disposed, isFalse);
      await engine.seekAllTo(1000);
      expect(fakePlatform.created[2].seekCalls, isEmpty,
          reason: 'a removed track no longer follows the timeline');
    });

    test('removeTrack with an unknown id does nothing', () async {
      await engine.loadSong(songWith(sopranoId: 's', contraltoId: 'c'));

      await engine.removeTrack('nope');

      expect(fakePlatform.created.every((p) => !p.disposed), isTrue);
    });

    test('adding a track does not change the position reference', () async {
      await engine.loadSong(songWith(sopranoId: 's', contraltoId: 'c'));
      final events = <int>[];
      final subscription = engine.positionMs.listen(events.add);
      await engine.addTrack(click);
      await Future<void>.delayed(Duration.zero);
      events.clear();

      fakePlatform.created[2].emitPlaybackEvent(PlaybackEventMessage(
        processingState: ProcessingStateMessage.ready,
        updateTime: DateTime.now(),
        updatePosition: const Duration(seconds: 7),
        bufferedPosition: const Duration(seconds: 7),
        duration: null,
        icyMetadata: null,
        currentIndex: 0,
        androidAudioSessionId: null,
      ));
      await Future<void>.delayed(Duration.zero);

      expect(events, isNot(contains(7000)));
      await subscription.cancel();
    });
  });

  group('setTrackStartDelayMs', () {
    test('changes only the internal map, without reloading the file', () async {
      await engine.loadSong(songWith(sopranoId: 's', contraltoId: 'c'));
      final sopranoPlatform = fakePlatform.created[0];
      final loadCallsBefore = sopranoPlatform.loadCalls.length;

      await engine.setTrackStartDelayMs('s', 500);

      expect(sopranoPlatform.loadCalls.length, loadCallsBefore);
    });

    test('a subsequent seekAllTo uses the new delay to compute local offset',
        () async {
      await engine.loadSong(songWith(sopranoId: 's', contraltoId: 'c'));
      final sopranoPlatform = fakePlatform.created[0];

      await engine.setTrackStartDelayMs('s', 500);
      await engine.seekAllTo(2000);

      expect(sopranoPlatform.seekCalls.last.position,
          const Duration(milliseconds: 1500));
    });
  });

  group('durationMs', () {
    test('is null before loadSong resolves', () {
      expect(engine.durationMs, isNull);
    });

    test('equals the maximum of startDelayMs + file duration across tracks',
        () async {
      fakePlatform.defaultLoadDuration = const Duration(seconds: 3);
      final song = songWith(
        sopranoId: 's',
        contraltoId: 'c',
        sopranoDelayMs: 1000,
      );

      await engine.loadSong(song);

      // soprano: 1000 + 3000 = 4000; contralto: 0 + 3000 = 3000 -> max 4000
      expect(engine.durationMs, 4000);
    });
  });

  group('positionMs', () {
    test('emits the reference track\'s position converted to timeline time',
        () async {
      final song = songWith(
        sopranoId: 's',
        contraltoId: 'c',
        sopranoDelayMs: 500,
      );
      await engine.loadSong(song);
      final referencePlatform = fakePlatform.created[0];

      final events = <int>[];
      final subscription = engine.positionMs.listen(events.add);

      referencePlatform.emitPlaybackEvent(PlaybackEventMessage(
        processingState: ProcessingStateMessage.ready,
        updateTime: DateTime.now(),
        updatePosition: const Duration(seconds: 2),
        bufferedPosition: const Duration(seconds: 2),
        duration: const Duration(seconds: 10),
        icyMetadata: null,
        currentIndex: 0,
        androidAudioSessionId: null,
      ));
      await Future<void>.delayed(Duration.zero);

      expect(events, contains(2500));
      await subscription.cancel();
    });

    // Regression (solo-metronome spec, bug 2): the position came from
    // playbackEventStream, which only emits on events (load, pause,
    // buffering). During steady playback on a device the clock froze.
    test('advances while playing, with no new playback event', () async {
      await engine.loadSong(songWith(sopranoId: 's', contraltoId: 'c'));
      final events = <int>[];
      final subscription = engine.positionMs.listen(events.add);

      await engine.playAt(DateTime.now());
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(events.where((ms) => ms >= 100), isNotEmpty,
          reason: 'the clock must move on its own while playing');
      await engine.pause();
      await subscription.cancel();
    });

    // Regression (solo-player design, Risks row 1): the position followed
    // tracks.first. When that track ends before the others, its player stops
    // emitting, the clock freezes and the end of the song is never reached.
    test('follows the track that ends last, not the first track', () async {
      fakePlatform.defaultLoadDuration = const Duration(seconds: 3);
      // soprano ends at 0 + 3000; contralto ends at 2000 + 3000 = 5000.
      await engine.loadSong(
        songWith(sopranoId: 's', contraltoId: 'c', contraltoDelayMs: 2000),
      );
      final sopranoPlatform = fakePlatform.created[0];
      final contraltoPlatform = fakePlatform.created[1];

      final events = <int>[];
      final subscription = engine.positionMs.listen(events.add);

      PlaybackEventMessage at(Duration position) => PlaybackEventMessage(
            processingState: ProcessingStateMessage.ready,
            updateTime: DateTime.now(),
            updatePosition: position,
            bufferedPosition: position,
            duration: const Duration(seconds: 3),
            icyMetadata: null,
            currentIndex: 0,
            androidAudioSessionId: null,
          );

      sopranoPlatform.emitPlaybackEvent(at(const Duration(milliseconds: 2900)));
      contraltoPlatform.emitPlaybackEvent(at(const Duration(seconds: 2)));
      await Future<void>.delayed(Duration.zero);

      // The fake also replays its load-time "ready" event (position 0) on
      // subscribe, so only the soprano's 2900 and the contralto's 4000 matter.
      expect(events, isNot(contains(2900)),
          reason: 'the shorter soprano must not drive the timeline');
      expect(events.last, 4000,
          reason: 'the contralto (longest) drives it: 2000 delay + 2000 local');
      await subscription.cancel();
    });
  });

  // Regression (solo-metronome spec, bug 1): playAt awaited each
  // player.play(), whose future completes only when playback pauses. On a
  // device only the first track ever started.
  group('playAt', () {
    test('starts every track even when play() answers only on pause', () async {
      await engine.loadSong(songWith(sopranoId: 's', contraltoId: 'c'));
      for (final player in fakePlatform.created) {
        player.holdPlayUntilPause = true;
      }

      unawaited(engine.playAt(DateTime.now()));
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(fakePlatform.created[0].playCalls, hasLength(1));
      expect(fakePlatform.created[1].playCalls, hasLength(1),
          reason: 'the second track must not wait for the first to pause');
      await engine.pause();
    });

    test('completes without waiting for playback to pause', () async {
      await engine.loadSong(songWith(sopranoId: 's', contraltoId: 'c'));
      for (final player in fakePlatform.created) {
        player.holdPlayUntilPause = true;
      }

      await expectLater(
        engine.playAt(DateTime.now()).timeout(const Duration(seconds: 1)),
        completes,
      );
      await engine.pause();
    });
  });

  group(
      'loadSong / seekAllTo (pre-existing behavior, now exercised by the fake)',
      () {
    test('loadSong sets up one player per track plus playback track', () async {
      await engine.loadSong(songWith(sopranoId: 's', contraltoId: 'c'));

      expect(fakePlatform.created, hasLength(2));
    });
  });
}
