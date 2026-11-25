import 'dart:async';

import 'package:cantae/domain/audio/audio_playback_engine.dart';
import 'package:cantae/domain/audio/click_track_builder.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/core/unit.dart';
import 'package:cantae/domain/entities/metronome_config.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/entities/song_origin.dart';
import 'package:cantae/domain/entities/song_track.dart';
import 'package:cantae/domain/repositories/song_repository.dart';
import 'package:cantae/presentation/providers/audio_playback_engine_provider.dart';
import 'package:cantae/presentation/providers/click_track_builder_provider.dart';
import 'package:cantae/presentation/providers/solo_player_notifier.dart';
import 'package:cantae/presentation/providers/song_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAudioPlaybackEngine implements AudioPlaybackEngine {
  bool throwOnLoad = false;
  int loadCount = 0;
  int? duration = 180000;
  final List<String> calls = [];
  final Map<String, double> volumes = {};
  final Map<String, bool> mutes = {};
  final List<String> soloCalls = [];
  final _positionController = StreamController<int>.broadcast();

  void emitPosition(int ms) => _positionController.add(ms);

  @override
  Future<void> loadSong(Song song) async {
    if (throwOnLoad) throw Exception('file missing');
    loadCount++;
    calls.add('load');
  }

  @override
  Future<void> playAt(DateTime scheduledStart) async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> seekAllTo(int timelineMs) async => calls.add('seek:$timelineMs');

  @override
  Future<void> setTrackMuted(String trackId, bool muted) async =>
      mutes[trackId] = muted;

  @override
  Future<void> setTrackSolo(String trackId, bool solo) async =>
      soloCalls.add('$trackId:$solo');

  @override
  Future<void> setTrackVolume(String trackId, double volume) async =>
      volumes[trackId] = volume;

  bool throwOnAddTrack = false;
  bool? lastAddExemptFromSolo;

  @override
  Future<void> addTrack(SongTrack track, {bool exemptFromSolo = false}) async {
    if (throwOnAddTrack) throw Exception('click unreadable');
    lastAddExemptFromSolo = exemptFromSolo;
    calls.add('add:${track.id}:${track.filePath}');
  }

  @override
  Future<void> removeTrack(String trackId) async =>
      calls.add('remove:$trackId');

  @override
  Future<void> setTrackStartDelayMs(String trackId, int startDelayMs) async {}

  @override
  int? get durationMs => duration;

  @override
  Stream<int> get positionMs => _positionController.stream;
}

class _FakeSongRepository implements SongRepository {
  _FakeSongRepository({this.song, this.failure});

  Song? song;
  Failure? failure;
  int getByIdCount = 0;

  @override
  Future<Result<Song, Failure>> getById(String id) async {
    getByIdCount++;
    final failure = this.failure;
    if (failure != null) return Result.failure(failure);
    final song = this.song;
    if (song == null) {
      return Result.failure(NotFoundFailure(code: 'song_not_found'));
    }
    return Result.success(song);
  }

  Song? savedSong;
  StorageFailure? saveFailure;

  @override
  Future<Result<Unit, StorageFailure>> save(Song song) async {
    final failure = saveFailure;
    if (failure != null) return Result.failure(failure);
    savedSong = song;
    this.song = song;
    return const Result.success(Unit());
  }

  @override
  Future<Result<List<Song>, StorageFailure>> getAll() async =>
      const Result.success(<Song>[]);

  @override
  Future<Result<Unit, Failure>> delete(String id) => throw UnimplementedError();

  @override
  Future<Result<Unit, StorageFailure>> deleteAll() =>
      throw UnimplementedError();

  @override
  Future<Result<Unit, Failure>> markRehearsed(String id, DateTime at) =>
      throw UnimplementedError();
}

class _FakeClickTrackBuilder implements ClickTrackBuilder {
  bool fail = false;
  final List<({MetronomeConfig config, int durationMs})> builds = [];

  @override
  Future<Result<String, Failure>> build({
    required String songId,
    required MetronomeConfig config,
    required int durationMs,
  }) async {
    builds.add((config: config, durationMs: durationMs));
    if (fail) {
      return Result.failure(PlaybackFailure(code: 'click_track_build_failed'));
    }
    return Result.success('/tmp/metronome_${songId}_${config.bpm}.wav');
  }
}

const _soprano = SongTrack(
  id: 'soprano',
  filePath: '/tmp/soprano.mp3',
  naipe: Naipe.soprano,
);
const _tenor = SongTrack(
  id: 'tenor',
  filePath: '/tmp/tenor.mp3',
  naipe: Naipe.tenor,
);
const _playback = SongTrack(
  id: 'playback',
  filePath: '/tmp/playback.mp3',
  naipe: Naipe.custom,
  isPlayback: true,
);

Song _song({
  List<SongTrack> tracks = const [_soprano, _tenor],
  SongTrack? playbackTrack,
  MetronomeConfig? metronomeConfig,
  SongOrigin origin = SongOrigin.created,
}) =>
    Song(
      id: 'ave',
      name: 'Ave Verum Corpus',
      author: 'Mozart',
      tracks: tracks,
      playbackTrack: playbackTrack,
      metronomeConfig: metronomeConfig,
      origin: origin,
    );

({
  ProviderContainer container,
  _FakeAudioPlaybackEngine engine,
  _FakeSongRepository repo,
  _FakeClickTrackBuilder builder,
}) _setUp({Song? song, bool notFound = false, Failure? failure}) {
  final engine = _FakeAudioPlaybackEngine();
  final builder = _FakeClickTrackBuilder();
  final repo = _FakeSongRepository(
    song: notFound ? null : (song ?? _song()),
    failure: failure,
  );
  final container = ProviderContainer(
    overrides: [
      audioPlaybackEngineProvider.overrideWithValue(engine),
      songRepositoryProvider.overrideWithValue(repo),
      clickTrackBuilderProvider.overrideWithValue(builder),
    ],
  );
  return (container: container, engine: engine, repo: repo, builder: builder);
}

/// `soloPlayerProvider` is `autoDispose`; `container.listen` keeps it alive
/// like the real screen's `ref.watch` would.
Future<void> _settle(ProviderContainer container) async {
  container.listen(soloPlayerProvider('ave'), (_, __) {});
  await _flush();
}

Future<void> _flush() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

SoloPlayerNotifier _notifier(ProviderContainer c) =>
    c.read(soloPlayerProvider('ave').notifier);

SoloPlayerState _state(ProviderContainer c) =>
    c.read(soloPlayerProvider('ave'));

/// Plays and puts the playback clock at [positionMs].
Future<void> _playAt(
  ProviderContainer c,
  _FakeAudioPlaybackEngine engine,
  int positionMs,
) async {
  await _notifier(c).togglePlay();
  engine.emitPosition(positionMs);
  await _flush();
}

void main() {
  group('statuses (SOLO-02, SOLO-23, SOLO-24, SOLO-25)', () {
    test('a song with tracks loads every track, paused at 0 with duration',
        () async {
      final s = _setUp();
      addTearDown(s.container.dispose);
      await _settle(s.container);

      final state = _state(s.container);
      expect(state.status, SoloPlayerStatus.ready);
      expect(state.positionMs, 0);
      expect(state.durationMs, 180000);
      expect(state.playing, isFalse);
      expect(s.engine.loadCount, 1);
    });

    test('mix rows: every naipe track, then the Playback track', () async {
      final s = _setUp(song: _song(playbackTrack: _playback));
      addTearDown(s.container.dispose);
      await _settle(s.container);

      expect(
        _state(s.container).mixTracks.map((t) => t.id).toList(),
        ['soprano', 'tenor', 'playback'],
      );
    });

    test('notFound when the song does not exist', () async {
      final s = _setUp(notFound: true);
      addTearDown(s.container.dispose);
      await _settle(s.container);

      expect(_state(s.container).status, SoloPlayerStatus.notFound);
      expect(s.engine.loadCount, 0);
    });

    test('a repository failure is an error; retry reads the song again',
        () async {
      final s = _setUp(failure: StorageFailure(code: 'db_read'));
      addTearDown(s.container.dispose);
      await _settle(s.container);
      expect(_state(s.container).status, SoloPlayerStatus.error);

      s.repo.failure = null;
      _notifier(s.container).retry();
      await _flush();

      expect(s.repo.getByIdCount, 2);
      expect(_state(s.container).status, SoloPlayerStatus.ready);
    });

    test('a song with no tracks is noTracks and never loads the engine',
        () async {
      final s = _setUp(song: _song(tracks: const []));
      addTearDown(s.container.dispose);
      await _settle(s.container);

      expect(_state(s.container).status, SoloPlayerStatus.noTracks);
      expect(s.engine.loadCount, 0);
    });

    test('an engine load failure is audioError; retry loads it again',
        () async {
      final s = _setUp();
      s.engine.throwOnLoad = true;
      addTearDown(s.container.dispose);
      await _settle(s.container);
      expect(_state(s.container).status, SoloPlayerStatus.audioError);

      s.engine.throwOnLoad = false;
      _notifier(s.container).retry();
      await _flush();

      expect(s.engine.loadCount, 1);
      expect(_state(s.container).status, SoloPlayerStatus.ready);
    });
  });

  group('play, pause, seek, end (SOLO-03 to SOLO-07)', () {
    test('togglePlay plays from the current position, then pauses', () async {
      final s = _setUp();
      addTearDown(s.container.dispose);
      await _settle(s.container);

      await _notifier(s.container).togglePlay();
      expect(_state(s.container).playing, isTrue);
      expect(s.engine.calls.last, 'play');

      await _notifier(s.container).togglePlay();
      expect(_state(s.container).playing, isFalse);
      expect(s.engine.calls.last, 'pause');
      expect(s.engine.calls.where((c) => c.startsWith('seek')), isEmpty,
          reason: 'play/pause never moves the position');
    });

    test('the position stream updates positionMs', () async {
      final s = _setUp();
      addTearDown(s.container.dispose);
      await _settle(s.container);

      await _playAt(s.container, s.engine, 5300);

      expect(_state(s.container).positionMs, 5300);
    });

    test('two quick taps end in the state of the last tap', () async {
      final s = _setUp();
      addTearDown(s.container.dispose);
      await _settle(s.container);

      final first = _notifier(s.container).togglePlay();
      final second = _notifier(s.container).togglePlay();
      await Future.wait([first, second]);

      expect(_state(s.container).playing, isFalse);
      expect(s.engine.calls.last, 'pause');
    });

    test('seekTo moves every track and keeps the playing state', () async {
      final s = _setUp();
      addTearDown(s.container.dispose);
      await _settle(s.container);
      await _notifier(s.container).togglePlay();

      await _notifier(s.container).seekTo(60000);

      expect(s.engine.calls.last, 'seek:60000');
      expect(_state(s.container).positionMs, 60000);
      expect(_state(s.container).playing, isTrue);
    });

    test('seekTo clamps to 0..duration', () async {
      final s = _setUp();
      addTearDown(s.container.dispose);
      await _settle(s.container);

      await _notifier(s.container).seekTo(999999);
      expect(s.engine.calls.last, 'seek:180000');

      await _notifier(s.container).seekTo(-50);
      expect(s.engine.calls.last, 'seek:0');
    });

    test('reaching the end pauses; the next play restarts from 0', () async {
      final s = _setUp();
      addTearDown(s.container.dispose);
      await _settle(s.container);
      await _playAt(s.container, s.engine, 180000);

      expect(_state(s.container).playing, isFalse);
      expect(_state(s.container).ended, isTrue);
      expect(s.engine.calls.last, 'pause');

      await _notifier(s.container).togglePlay();

      expect(s.engine.calls.sublist(s.engine.calls.length - 2),
          ['seek:0', 'play']);
      expect(_state(s.container).positionMs, 0);
      expect(_state(s.container).ended, isFalse);
    });

    test('disposing the provider stops the audio', () async {
      final s = _setUp();
      await _settle(s.container);
      await _notifier(s.container).togglePlay();

      s.container.dispose();

      expect(s.engine.calls.last, 'stop');
    });
  });

  group('mix (SOLO-10 to SOLO-13)', () {
    test('every track starts at 100 %, unmuted, nothing soloed', () async {
      final s = _setUp();
      addTearDown(s.container.dispose);
      await _settle(s.container);

      final state = _state(s.container);
      expect(state.mix['soprano']!.volume, 1.0);
      expect(state.mix['tenor']!.muted, isFalse);
      expect(state.soloTrackId, isNull);
    });

    test('setVolume changes only that track, clamped to 0..1', () async {
      final s = _setUp();
      addTearDown(s.container.dispose);
      await _settle(s.container);

      await _notifier(s.container).setVolume('tenor', 0.3);
      expect(_state(s.container).mix['tenor']!.volume, 0.3);
      expect(_state(s.container).mix['soprano']!.volume, 1.0);
      expect(s.engine.volumes, {'tenor': 0.3});

      await _notifier(s.container).setVolume('tenor', 1.4);
      expect(_state(s.container).mix['tenor']!.volume, 1.0);
      expect(s.engine.volumes['tenor'], 1.0);
    });

    test('toggleMute mutes, and again restores the track', () async {
      final s = _setUp();
      addTearDown(s.container.dispose);
      await _settle(s.container);

      await _notifier(s.container).toggleMute('soprano');
      expect(_state(s.container).mix['soprano']!.muted, isTrue);
      expect(s.engine.mutes['soprano'], isTrue);

      await _notifier(s.container).toggleMute('soprano');
      expect(_state(s.container).mix['soprano']!.muted, isFalse);
      expect(s.engine.mutes['soprano'], isFalse);
    });

    test('toggleSolo is exclusive, and again on the same track undoes it',
        () async {
      final s = _setUp();
      addTearDown(s.container.dispose);
      await _settle(s.container);

      await _notifier(s.container).toggleSolo('soprano');
      expect(_state(s.container).soloTrackId, 'soprano');

      await _notifier(s.container).toggleSolo('tenor');
      expect(_state(s.container).soloTrackId, 'tenor');

      await _notifier(s.container).toggleSolo('tenor');
      expect(_state(s.container).soloTrackId, isNull);
      expect(s.engine.soloCalls, ['soprano:true', 'tenor:true', 'tenor:false']);
    });

    test('a fresh screen starts with a fresh mix', () async {
      final first = _setUp();
      await _settle(first.container);
      await _notifier(first.container).setVolume('tenor', 0.2);
      first.container.dispose();

      final second = _setUp();
      addTearDown(second.container.dispose);
      await _settle(second.container);

      expect(_state(second.container).mix['tenor']!.volume, 1.0);
    });
  });

  group('loop (SOLO-14 to SOLO-17)', () {
    test('markLoopStart while playing keeps the current instant', () async {
      final s = _setUp();
      addTearDown(s.container.dispose);
      await _settle(s.container);
      await _playAt(s.container, s.engine, 41000);

      _notifier(s.container).markLoopStart();

      expect(_state(s.container).loopStartMs, 41000);
      expect(_state(s.container).loop, isNull);
    });

    test('marking does nothing while paused', () async {
      final s = _setUp();
      addTearDown(s.container.dispose);
      await _settle(s.container);
      await _notifier(s.container).seekTo(41000);

      _notifier(s.container).markLoopStart();

      expect(_state(s.container).loopStartMs, isNull);
    });

    // Regression (sensor S9): only the start was checked while paused, so
    // marking the end while paused went unnoticed (spec P3-AC7).
    test('marking the end does nothing while paused', () async {
      final s = _setUp();
      addTearDown(s.container.dispose);
      await _settle(s.container);
      await _playAt(s.container, s.engine, 41000);
      _notifier(s.container).markLoopStart();
      s.engine.emitPosition(72000);
      await _flush();
      await _notifier(s.container).togglePlay(); // pause

      _notifier(s.container).markLoopEnd();

      expect(_state(s.container).loop, isNull);
      expect(_state(s.container).loopStartMs, 41000);
    });

    test('markLoopEnd after the start turns the loop on', () async {
      final s = _setUp();
      addTearDown(s.container.dispose);
      await _settle(s.container);
      await _playAt(s.container, s.engine, 41000);
      _notifier(s.container).markLoopStart();
      s.engine.emitPosition(72000);
      await _flush();

      _notifier(s.container).markLoopEnd();

      final loop = _state(s.container).loop!;
      expect(loop.startMs, 41000);
      expect(loop.endMs, 72000);
      expect(_state(s.container).loopStartMs, isNull);
      expect(_state(s.container).loopError, isNull);
    });

    test('an end at or before the start is refused; the start stays', () async {
      final s = _setUp();
      addTearDown(s.container.dispose);
      await _settle(s.container);
      await _playAt(s.container, s.engine, 41000);
      _notifier(s.container).markLoopStart();

      _notifier(s.container).markLoopEnd(); // same instant

      expect(_state(s.container).loop, isNull);
      expect(_state(s.container).loopStartMs, 41000);
      expect(_state(s.container).loopError,
          'O fim do trecho precisa vir depois do início.');
    });

    test('reaching the loop end jumps every track back to the start', () async {
      final s = _setUp();
      addTearDown(s.container.dispose);
      await _settle(s.container);
      await _playAt(s.container, s.engine, 41000);
      _notifier(s.container).markLoopStart();
      s.engine.emitPosition(72000);
      await _flush();
      _notifier(s.container).markLoopEnd();

      s.engine.emitPosition(72000);
      await _flush();

      expect(s.engine.calls.last, 'seek:41000');
      expect(_state(s.container).positionMs, 41000);
      expect(_state(s.container).playing, isTrue);
    });

    test('clearLoop drops the section and keeps the position (no seek)',
        () async {
      final s = _setUp();
      addTearDown(s.container.dispose);
      await _settle(s.container);
      await _playAt(s.container, s.engine, 41000);
      _notifier(s.container).markLoopStart();
      s.engine.emitPosition(72000);
      await _flush();
      _notifier(s.container).markLoopEnd();
      s.engine.emitPosition(50000);
      await _flush();
      final callsBefore = s.engine.calls.length;

      _notifier(s.container).clearLoop();

      expect(_state(s.container).loop, isNull);
      expect(_state(s.container).positionMs, 50000);
      expect(s.engine.calls.length, callsBefore);
    });
  });

  group('metronome (MET-04 to MET-18)', () {
    const tempo72 = MetronomeConfig(bpm: 72, beatsPerMeasure: 4);

    test('turning it on builds the click and adds it, aligned to now',
        () async {
      final s = _setUp(song: _song(metronomeConfig: tempo72));
      addTearDown(s.container.dispose);
      await _settle(s.container);
      await _notifier(s.container).seekTo(41000);

      await _notifier(s.container).toggleMetronome();

      expect(s.builder.builds.single.config.bpm, 72);
      expect(s.builder.builds.single.durationMs, 180000);
      expect(
          s.engine.calls, contains('add:metronome:/tmp/metronome_ave_72.wav'));
      expect(s.engine.lastAddExemptFromSolo, isTrue,
          reason: 'soloing a voice must not silence the click');
      expect(s.engine.calls.last, 'seek:41000');
      expect(_state(s.container).metronomeOn, isTrue);
    });

    test('turning it on while playing: pause, add, seek, play', () async {
      final s = _setUp(song: _song(metronomeConfig: tempo72));
      addTearDown(s.container.dispose);
      await _settle(s.container);
      await _playAt(s.container, s.engine, 5000);
      s.engine.calls.clear();

      await _notifier(s.container).toggleMetronome();

      expect(s.engine.calls.first, 'pause');
      expect(s.engine.calls.sublist(s.engine.calls.length - 2),
          ['seek:5000', 'play']);
      expect(_state(s.container).playing, isTrue);
    });

    test('turning it off removes only the click; the voices keep playing',
        () async {
      final s = _setUp(song: _song(metronomeConfig: tempo72));
      addTearDown(s.container.dispose);
      await _settle(s.container);
      await _playAt(s.container, s.engine, 5000);
      await _notifier(s.container).toggleMetronome();
      s.engine.calls.clear();

      await _notifier(s.container).toggleMetronome();

      expect(s.engine.calls, ['remove:metronome']);
      expect(_state(s.container).metronomeOn, isFalse);
      expect(_state(s.container).playing, isTrue);
    });

    test('a build failure keeps it off, shows the error, music untouched',
        () async {
      final s = _setUp(song: _song(metronomeConfig: tempo72));
      addTearDown(s.container.dispose);
      await _settle(s.container);
      await _playAt(s.container, s.engine, 5000);
      s.builder.fail = true;
      s.engine.calls.clear();

      await _notifier(s.container).toggleMetronome();

      expect(_state(s.container).metronomeOn, isFalse);
      expect(_state(s.container).metronomeError,
          'Não foi possível preparar o metrônomo.');
      expect(s.engine.calls, isEmpty);
      expect(_state(s.container).playing, isTrue);
    });

    test('an unreadable click file keeps it off and resumes the music',
        () async {
      final s = _setUp(song: _song(metronomeConfig: tempo72));
      addTearDown(s.container.dispose);
      await _settle(s.container);
      await _playAt(s.container, s.engine, 5000);
      s.engine.throwOnAddTrack = true;

      await _notifier(s.container).toggleMetronome();

      expect(_state(s.container).metronomeOn, isFalse);
      expect(_state(s.container).metronomeError,
          'Não foi possível preparar o metrônomo.');
      expect(s.engine.calls.last, 'play');
    });

    test('without a tempo, toggling does nothing', () async {
      final s = _setUp();
      addTearDown(s.container.dispose);
      await _settle(s.container);

      await _notifier(s.container).toggleMetronome();

      expect(s.builder.builds, isEmpty);
      expect(_state(s.container).metronomeOn, isFalse);
    });

    test('"ligar ao abrir" turns it on once the song is ready', () async {
      final s = _setUp(
        song: _song(
          metronomeConfig: const MetronomeConfig(
            bpm: 72,
            beatsPerMeasure: 4,
            enabledByDefault: true,
          ),
        ),
      );
      addTearDown(s.container.dispose);
      await _settle(s.container);

      expect(_state(s.container).metronomeOn, isTrue);
      expect(s.builder.builds, hasLength(1));
    });

    test('saveTempo saves the tempo, keeps enabledByDefault, turns it on',
        () async {
      final s = _setUp(
        song: _song(
          metronomeConfig: const MetronomeConfig(
            bpm: 60,
            beatsPerMeasure: 4,
            enabledByDefault: true,
          ),
        ),
      );
      addTearDown(s.container.dispose);
      await _settle(s.container);
      await _notifier(s.container).toggleMetronome(); // off after auto-on

      final saved = await _notifier(s.container).saveTempo(
        const MetronomeConfig(
          bpm: 96,
          beatsPerMeasure: 3,
          downbeatAccent: false,
        ),
      );
      await _flush();

      expect(saved, isTrue);
      final config = s.repo.savedSong!.metronomeConfig!;
      expect(config.bpm, 96);
      expect(config.beatsPerMeasure, 3);
      expect(config.downbeatAccent, isFalse);
      expect(config.enabledByDefault, isTrue);
      expect(_state(s.container).metronomeConfig!.bpm, 96);
      expect(_state(s.container).metronomeOn, isTrue);
      expect(s.builder.builds.last.config.bpm, 96);
    });

    test('saveTempo with the metronome on swaps the click for the new one',
        () async {
      final s = _setUp(song: _song(metronomeConfig: tempo72));
      addTearDown(s.container.dispose);
      await _settle(s.container);
      await _notifier(s.container).toggleMetronome();
      s.engine.calls.clear();

      await _notifier(s.container).saveTempo(
        const MetronomeConfig(bpm: 96, beatsPerMeasure: 4),
      );

      expect(s.engine.calls.first, 'remove:metronome');
      expect(
          s.engine.calls, contains('add:metronome:/tmp/metronome_ave_96.wav'));
      expect(_state(s.container).metronomeOn, isTrue);
    });

    test('a failed save keeps the metronome as it was and reports it',
        () async {
      final s = _setUp();
      addTearDown(s.container.dispose);
      await _settle(s.container);
      s.repo.saveFailure = StorageFailure(code: 'db_write');

      final saved = await _notifier(s.container).saveTempo(tempo72);

      expect(saved, isFalse);
      expect(_state(s.container).tempoSaveError,
          'Não foi possível salvar o andamento.');
      expect(_state(s.container).metronomeOn, isFalse);
      expect(s.builder.builds, isEmpty);
    });

    test('a received song cannot have its tempo saved', () async {
      final s = _setUp(song: _song(origin: SongOrigin.received));
      addTearDown(s.container.dispose);
      await _settle(s.container);

      final saved = await _notifier(s.container).saveTempo(tempo72);

      expect(saved, isFalse);
      expect(s.repo.savedSong, isNull);
      expect(_state(s.container).canEditTempo, isFalse);
    });

    test('volume and mute reach only the click track', () async {
      final s = _setUp(song: _song(metronomeConfig: tempo72));
      addTearDown(s.container.dispose);
      await _settle(s.container);
      await _notifier(s.container).toggleMetronome();

      await _notifier(s.container).setMetronomeVolume(0.4);
      await _notifier(s.container).toggleMetronomeMute();

      expect(s.engine.volumes, {'metronome': 0.4});
      expect(s.engine.mutes, {'metronome': true});
      expect(_state(s.container).metronomeVolume, 0.4);
      expect(_state(s.container).metronomeMuted, isTrue);
    });

    test('a volume chosen before turning it on is applied when it starts',
        () async {
      final s = _setUp(song: _song(metronomeConfig: tempo72));
      addTearDown(s.container.dispose);
      await _settle(s.container);
      await _notifier(s.container).setMetronomeVolume(1.7);
      expect(_state(s.container).metronomeVolume, 1.0, reason: 'clamped');
      await _notifier(s.container).setMetronomeVolume(0.25);

      await _notifier(s.container).toggleMetronome();

      expect(s.engine.volumes['metronome'], 0.25);
    });

    test('a fresh screen starts with the click at 100 %, unmuted', () async {
      final s = _setUp(song: _song(metronomeConfig: tempo72));
      addTearDown(s.container.dispose);
      await _settle(s.container);

      expect(_state(s.container).metronomeVolume, 1.0);
      expect(_state(s.container).metronomeMuted, isFalse);
      expect(_state(s.container).metronomeOn, isFalse);
    });
  });
}
