import 'dart:async';

import 'package:cantae/domain/audio/audio_playback_engine.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/core/unit.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/entities/song_track.dart';
import 'package:cantae/domain/repositories/song_repository.dart';
import 'package:cantae/presentation/providers/audio_playback_engine_provider.dart';
import 'package:cantae/presentation/providers/song_detail_providers.dart';
import 'package:cantae/presentation/providers/song_repository_provider.dart';
import 'package:cantae/presentation/providers/track_align_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAudioPlaybackEngine implements AudioPlaybackEngine {
  Song? loadedSong;
  bool throwOnLoad = false;
  int? durationMsValue;
  final List<String> playAtCalls = [];
  final List<int> seekAllToCalls = [];
  bool stopped = false;
  final Map<String, bool> mutedCalls = {};
  final Map<String, bool> soloCalls = {};
  final Map<String, int> startDelayCalls = {};
  final _positionController = StreamController<int>.broadcast();

  void emitPosition(int ms) => _positionController.add(ms);

  @override
  Future<void> loadSong(Song song) async {
    if (throwOnLoad) throw Exception('load failed');
    loadedSong = song;
  }

  @override
  Future<void> playAt(DateTime scheduledStart) async {
    playAtCalls.add(scheduledStart.toIso8601String());
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {
    stopped = true;
  }

  @override
  Future<void> seekAllTo(int timelineMs) async {
    seekAllToCalls.add(timelineMs);
  }

  @override
  Future<void> setTrackMuted(String trackId, bool muted) async {
    mutedCalls[trackId] = muted;
  }

  @override
  Future<void> setTrackSolo(String trackId, bool solo) async {
    soloCalls[trackId] = solo;
  }

  @override
  Future<void> setTrackVolume(String trackId, double volume) async {}

  @override
  Future<void> setTrackStartDelayMs(String trackId, int startDelayMs) async {
    startDelayCalls[trackId] = startDelayMs;
  }

  @override
  int? get durationMs => durationMsValue;

  @override
  Stream<int> get positionMs => _positionController.stream;
}

class _FakeSongRepository implements SongRepository {
  _FakeSongRepository({required this.initialSong, this.saveResult});

  Song? initialSong;
  Result<Unit, StorageFailure>? saveResult;
  Song? savedSong;

  @override
  Future<Result<Song, Failure>> getById(String id) async {
    final song = initialSong;
    if (song == null) {
      return Result.failure(NotFoundFailure(code: 'song_not_found'));
    }
    return Result.success(song);
  }

  @override
  Future<Result<Unit, StorageFailure>> save(Song song) async {
    savedSong = song;
    return saveResult ?? const Result.success(Unit());
  }

  @override
  Future<Result<List<Song>, StorageFailure>> getAll() =>
      throw UnimplementedError();

  @override
  Future<Result<Unit, Failure>> delete(String id) => throw UnimplementedError();

  @override
  Future<Result<Unit, StorageFailure>> deleteAll() =>
      throw UnimplementedError();

  @override
  Future<Result<Unit, Failure>> markRehearsed(String id, DateTime at) =>
      throw UnimplementedError();
}

Song _songWith({int sopranoDelayMs = 0}) => Song(
      id: 'song-1',
      name: 'Ave Maria',
      author: 'Caccini',
      tracks: [
        SongTrack(
          id: 'soprano',
          filePath: '/tmp/soprano.mp3',
          naipe: Naipe.soprano,
          startDelayMs: sopranoDelayMs,
        ),
        const SongTrack(
          id: 'contralto',
          filePath: '/tmp/contralto.mp3',
          naipe: Naipe.contralto,
        ),
      ],
    );

({
  ProviderContainer container,
  _FakeAudioPlaybackEngine engine,
  _FakeSongRepository repo
}) _setUp({
  Song? initialSong,
  bool songNotFound = false,
  Result<Unit, StorageFailure>? saveResult,
}) {
  final engine = _FakeAudioPlaybackEngine();
  final repo = _FakeSongRepository(
    initialSong: songNotFound ? null : (initialSong ?? _songWith()),
    saveResult: saveResult,
  );
  final container = ProviderContainer(
    overrides: [
      audioPlaybackEngineProvider.overrideWithValue(engine),
      songRepositoryProvider.overrideWithValue(repo),
    ],
  );
  return (container: container, engine: engine, repo: repo);
}

/// `trackAlignProvider` is `autoDispose` (so a loop test stops when the
/// real screen unmounts) — a bare `container.read` would tear it right back
/// down with no listener attached. `container.listen` pins it alive for the
/// container's lifetime, same as the real screen's `ref.watch` would.
/// Constructs the notifier, waits for `songByIdProvider` to resolve, then
/// flushes the microtask queue a few more times so
/// `TrackAlignNotifier._onSongLoaded`'s own `await engine.loadSong(...)`
/// tail has a chance to complete too.
Future<void> _settle(ProviderContainer container, String id) async {
  container.listen(trackAlignProvider(id), (_, __) {});
  await container.read(songByIdProvider(id).future);
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('TrackAlignNotifier states', () {
    test('noTracks when the song has no tracks', () async {
      final setup = _setUp(
        initialSong: const Song(id: 's', name: 'N', author: 'A'),
      );
      addTearDown(setup.container.dispose);

      await _settle(setup.container, 's');
      final state = setup.container.read(trackAlignProvider('s'));

      expect(state.status, TrackAlignStatus.noTracks);
    });

    test('notFound when the repository returns NotFoundFailure', () async {
      final setup = _setUp(songNotFound: true);
      addTearDown(setup.container.dispose);

      await _settle(setup.container, 'missing');
      final state = setup.container.read(trackAlignProvider('missing'));

      expect(state.status, TrackAlignStatus.notFound);
    });

    test('error when the engine fails to load', () async {
      final setup = _setUp();
      setup.engine.throwOnLoad = true;
      addTearDown(setup.container.dispose);

      await _settle(setup.container, 'song-1');
      final state = setup.container.read(trackAlignProvider('song-1'));

      expect(state.status, TrackAlignStatus.error);
    });

    test('loaded once the song and engine resolve successfully', () async {
      final setup = _setUp();
      addTearDown(setup.container.dispose);

      await _settle(setup.container, 'song-1');
      final state = setup.container.read(trackAlignProvider('song-1'));

      expect(state.status, TrackAlignStatus.loaded);
      expect(setup.engine.loadedSong?.id, 'song-1');
    });
  });

  group('setOffset', () {
    test('a valid edit updates the draft and marks unsaved', () async {
      final setup = _setUp();
      addTearDown(setup.container.dispose);
      final notifier =
          setup.container.read(trackAlignProvider('song-1').notifier);
      await _settle(setup.container, 'song-1');

      await notifier.setOffset('soprano', 1500);

      final state = setup.container.read(trackAlignProvider('song-1'));
      expect(state.startDelayMsByTrackId['soprano'], 1500);
      expect(state.hasUnsavedChanges, isTrue);
      expect(setup.engine.startDelayCalls['soprano'], 1500);
    });

    test('a negative value is rejected, keeping the last valid value',
        () async {
      final setup = _setUp();
      addTearDown(setup.container.dispose);
      final notifier =
          setup.container.read(trackAlignProvider('song-1').notifier);
      await _settle(setup.container, 'song-1');

      await notifier.setOffset('soprano', -10);

      final state = setup.container.read(trackAlignProvider('song-1'));
      expect(state.startDelayMsByTrackId['soprano'], 0);
      expect(state.hasUnsavedChanges, isFalse);
    });
  });

  group('mute/solo', () {
    test('setMuted calls engine.setTrackMuted and updates visual state',
        () async {
      final setup = _setUp();
      addTearDown(setup.container.dispose);
      final notifier =
          setup.container.read(trackAlignProvider('song-1').notifier);
      await _settle(setup.container, 'song-1');

      await notifier.setMuted('soprano', true);

      expect(setup.engine.mutedCalls['soprano'], isTrue);
      expect(
        setup.container
            .read(trackAlignProvider('song-1'))
            .mutedByTrackId['soprano'],
        isTrue,
      );
    });

    test('setSolo calls engine.setTrackSolo and is exclusive in the store',
        () async {
      final setup = _setUp();
      addTearDown(setup.container.dispose);
      final notifier =
          setup.container.read(trackAlignProvider('song-1').notifier);
      await _settle(setup.container, 'song-1');

      await notifier.setSolo('soprano', true);
      await notifier.setSolo('contralto', true);

      final state = setup.container.read(trackAlignProvider('song-1'));
      expect(state.soloTrackId, 'contralto');
      expect(setup.engine.soloCalls['contralto'], isTrue);
    });
  });

  group('loop region + test', () {
    test('rejects end <= start, keeping the last valid value', () async {
      final setup = _setUp();
      setup.engine.durationMsValue = 10000;
      addTearDown(setup.container.dispose);
      final notifier =
          setup.container.read(trackAlignProvider('song-1').notifier);
      await _settle(setup.container, 'song-1');

      notifier.setLoopEnd(0);

      expect(
          setup.container.read(trackAlignProvider('song-1')).loopEndMs, 2000);
    });

    test('rejects end > known duration', () async {
      final setup = _setUp();
      setup.engine.durationMsValue = 5000;
      addTearDown(setup.container.dispose);
      final notifier =
          setup.container.read(trackAlignProvider('song-1').notifier);
      await _settle(setup.container, 'song-1');

      notifier.setLoopEnd(6000);

      expect(
          setup.container.read(trackAlignProvider('song-1')).loopEndMs, 2000);
    });

    test(
        'toggleTest seeks to start and plays, then stop cancels the subscription',
        () async {
      final setup = _setUp();
      setup.engine.durationMsValue = 10000;
      addTearDown(setup.container.dispose);
      final notifier =
          setup.container.read(trackAlignProvider('song-1').notifier);
      await _settle(setup.container, 'song-1');
      notifier.setLoopStart(0);
      notifier.setLoopEnd(2000);

      await notifier.toggleTest();

      expect(setup.engine.seekAllToCalls, contains(0));
      expect(setup.engine.playAtCalls, isNotEmpty);
      expect(
          setup.container.read(trackAlignProvider('song-1')).testing, isTrue);

      await notifier.toggleTest();

      expect(setup.engine.stopped, isTrue);
      expect(
          setup.container.read(trackAlignProvider('song-1')).testing, isFalse);
    });

    test('reaching the loop end repositions to the loop start', () async {
      final setup = _setUp();
      setup.engine.durationMsValue = 10000;
      addTearDown(setup.container.dispose);
      final notifier =
          setup.container.read(trackAlignProvider('song-1').notifier);
      await _settle(setup.container, 'song-1');
      notifier.setLoopStart(500);
      notifier.setLoopEnd(2000);

      await notifier.toggleTest();
      setup.engine.emitPosition(2500);
      await Future<void>.delayed(Duration.zero);

      expect(setup.engine.seekAllToCalls.last, 500);
    });
  });

  group('save', () {
    test(
        'calls SongRepository.save with the rebuilt song; success invalidates '
        'songsProvider and clears unsaved', () async {
      final setup = _setUp();
      addTearDown(setup.container.dispose);
      final notifier =
          setup.container.read(trackAlignProvider('song-1').notifier);
      await _settle(setup.container, 'song-1');
      await notifier.setOffset('soprano', 1500);

      await notifier.save();

      final savedTrack =
          setup.repo.savedSong!.tracks.firstWhere((t) => t.id == 'soprano');
      expect(savedTrack.startDelayMs, 1500);
      final state = setup.container.read(trackAlignProvider('song-1'));
      expect(state.hasUnsavedChanges, isFalse);
      expect(state.saveError, isNull);
    });

    test('failure keeps the state and exposes an error', () async {
      final setup = _setUp(
        saveResult: Result.failure(StorageFailure(code: 'save_failed')),
      );
      addTearDown(setup.container.dispose);
      final notifier =
          setup.container.read(trackAlignProvider('song-1').notifier);
      await _settle(setup.container, 'song-1');
      await notifier.setOffset('soprano', 1500);

      await notifier.save();

      final state = setup.container.read(trackAlignProvider('song-1'));
      expect(state.hasUnsavedChanges, isTrue);
      expect(state.saveError, isNotNull);
    });
  });

  group('hasUnsavedChanges', () {
    test('mute/solo/loop edits never set hasUnsavedChanges', () async {
      final setup = _setUp();
      setup.engine.durationMsValue = 10000;
      addTearDown(setup.container.dispose);
      final notifier =
          setup.container.read(trackAlignProvider('song-1').notifier);
      await _settle(setup.container, 'song-1');

      await notifier.setMuted('soprano', true);
      await notifier.setSolo('contralto', true);
      notifier.setLoopStart(100);
      notifier.setLoopEnd(2000);

      expect(
        setup.container.read(trackAlignProvider('song-1')).hasUnsavedChanges,
        isFalse,
      );
    });
  });

  group('autoDispose', () {
    test('stops playback once nothing is watching the provider anymore',
        () async {
      final setup = _setUp();
      setup.engine.durationMsValue = 10000;
      addTearDown(setup.container.dispose);
      final subscription =
          setup.container.listen(trackAlignProvider('song-1'), (_, __) {});
      final notifier =
          setup.container.read(trackAlignProvider('song-1').notifier);
      await setup.container.read(songByIdProvider('song-1').future);
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      notifier.setLoopStart(0);
      notifier.setLoopEnd(2000);
      await notifier.toggleTest();
      expect(
          setup.container.read(trackAlignProvider('song-1')).testing, isTrue);

      subscription.close();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(setup.engine.stopped, isTrue);
    });
  });
}
