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
