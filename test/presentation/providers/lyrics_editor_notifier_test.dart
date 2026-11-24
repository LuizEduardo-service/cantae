import 'dart:async';

import 'package:cantae/domain/audio/audio_playback_engine.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/core/unit.dart';
import 'package:cantae/domain/entities/lyric_line.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/entities/song_track.dart';
import 'package:cantae/domain/repositories/song_repository.dart';
import 'package:cantae/presentation/providers/audio_playback_engine_provider.dart';
import 'package:cantae/presentation/providers/lyrics_editor_notifier.dart';
import 'package:cantae/presentation/providers/song_detail_providers.dart';
import 'package:cantae/presentation/providers/song_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAudioPlaybackEngine implements AudioPlaybackEngine {
  bool throwOnLoad = false;
  int loadCount = 0;
  final List<String> calls = [];
  final List<int> seekAllToCalls = [];
  final _positionController = StreamController<int>.broadcast();

  void emitPosition(int ms) => _positionController.add(ms);

  @override
  Future<void> loadSong(Song song) async {
    if (throwOnLoad) throw Exception('load failed');
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
  Future<void> seekAllTo(int timelineMs) async {
    seekAllToCalls.add(timelineMs);
    calls.add('seek:$timelineMs');
  }

  @override
  Future<void> setTrackMuted(String trackId, bool muted) async {}

  @override
  Future<void> setTrackSolo(String trackId, bool solo) async {}

  @override
  Future<void> setTrackStartDelayMs(String trackId, int startDelayMs) async {}

  @override
  int? get durationMs => 180000;

  @override
  Stream<int> get positionMs => _positionController.stream;
}

class _FakeSongRepository implements SongRepository {
  _FakeSongRepository({required this.initialSong});

  Song? initialSong;
  Result<Unit, StorageFailure>? saveResult;
  Song? savedSong;
  int getByIdCount = 0;

  @override
  Future<Result<Song, Failure>> getById(String id) async {
    getByIdCount++;
    final song = savedSong ?? initialSong;
    if (song == null) {
      return Result.failure(NotFoundFailure(code: 'song_not_found'));
    }
    return Result.success(song);
  }

  @override
  Future<Result<Unit, StorageFailure>> save(Song song) async {
    final result = saveResult ?? const Result.success(Unit());
    if (result.isSuccess) savedSong = song;
    return result;
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

const _soprano = SongTrack(
  id: 'soprano',
  filePath: '/tmp/soprano.mp3',
  naipe: Naipe.soprano,
);

Song _song({
  List<LyricLine> lyrics = const [],
  List<SongTrack> tracks = const [_soprano],
}) =>
    Song(
      id: 'ave',
      name: 'Ave Verum Corpus',
      author: 'Mozart',
      tracks: tracks,
      lyrics: lyrics,
    );

({
  ProviderContainer container,
  _FakeAudioPlaybackEngine engine,
  _FakeSongRepository repo,
}) _setUp({Song? song, bool notFound = false}) {
  final engine = _FakeAudioPlaybackEngine();
  final repo = _FakeSongRepository(
    initialSong: notFound ? null : (song ?? _song()),
  );
  final container = ProviderContainer(
    overrides: [
      audioPlaybackEngineProvider.overrideWithValue(engine),
      songRepositoryProvider.overrideWithValue(repo),
    ],
  );
  return (container: container, engine: engine, repo: repo);
}

/// `lyricsEditorProvider` is `autoDispose`; `container.listen` keeps it
/// alive like the real screen's `ref.watch` would.
Future<void> _settle(ProviderContainer container) async {
  container.listen(lyricsEditorProvider('ave'), (_, __) {});
  await container.read(songByIdProvider('ave').future);
  await _flush();
}

Future<void> _flush() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

LyricsEditorNotifier _notifier(ProviderContainer c) =>
    c.read(lyricsEditorProvider('ave').notifier);

LyricsEditorState _state(ProviderContainer c) =>
    c.read(lyricsEditorProvider('ave'));

/// Starts marking mode and puts the playback clock at [positionMs].
Future<void> _previewAt(
  ProviderContainer c,
  _FakeAudioPlaybackEngine engine,
  int positionMs,
) async {
  await _notifier(c).togglePreview();
  engine.emitPosition(positionMs);
  await _flush();
}

void main() {
  group('LyricsEditorNotifier states (LYR-19, LYR-18)', () {
    test('loaded exposes the saved lyrics as draft lines, in order', () async {
      final s = _setUp(
        song: _song(lyrics: const [
          LyricLine(text: 'Ave verum corpus', onsetMs: 1000),
          LyricLine(text: 'natum de Maria Virgine', onsetMs: null),
        ]),
      );
      addTearDown(s.container.dispose);
      await _settle(s.container);

      final state = _state(s.container);
      expect(state.status, LyricsEditorStatus.loaded);
      expect(state.lines.map((l) => l.text).toList(),
          ['Ave verum corpus', 'natum de Maria Virgine']);
      expect(state.lines.map((l) => l.onsetMs).toList(), [1000, null]);
      expect(state.hasUnsavedChanges, isFalse);
    });

    test('notFound when the repository has no such song', () async {
      final s = _setUp(notFound: true);
      addTearDown(s.container.dispose);
      await _settle(s.container);

      expect(_state(s.container).status, LyricsEditorStatus.notFound);
    });

    test('a song with no tracks is still loaded (banner, never a block)',
        () async {
      final s = _setUp(song: _song(tracks: const []));
      addTearDown(s.container.dispose);
      await _settle(s.container);

      expect(_state(s.container).status, LyricsEditorStatus.loaded);
    });
  });

  group('editing lines (LYR-01, LYR-02, LYR-14, LYR-15)', () {
    // Regression: the design's addLine built `LyricLine(text: '')`, which
    // the domain assert rejects. A new line must be a draft with empty text.
    test('addLine appends an empty draft, expands it and marks unsaved',
        () async {
      final s = _setUp(
        song: _song(lyrics: const [LyricLine(text: 'Ave', onsetMs: 0)]),
      );
      addTearDown(s.container.dispose);
      await _settle(s.container);

      _notifier(s.container).addLine();

      final state = _state(s.container);
      expect(state.lines, hasLength(2));
      final added = state.lines.last;
      expect(added.text, '');
      expect(added.onsetMs, isNull);
      expect(added.naipe, isNull);
      expect(added.dynamics, isNull);
      expect(state.expandedIndex, 1);
      expect(state.hasUnsavedChanges, isTrue);
    });

    test('updateText accepts 1..200 chars and rejects empty or >200', () async {
      final s = _setUp(
        song: _song(lyrics: const [LyricLine(text: 'Ave', onsetMs: null)]),
      );
      addTearDown(s.container.dispose);
      await _settle(s.container);
      final notifier = _notifier(s.container);

      notifier.updateText(0, '');
      expect(_state(s.container).lines[0].text, 'Ave');
      expect(_state(s.container).hasUnsavedChanges, isFalse);

      notifier.updateText(0, 'x' * 201);
      expect(_state(s.container).lines[0].text, 'Ave');

      notifier.updateText(0, 'x' * 200);
      expect(_state(s.container).lines[0].text, 'x' * 200);
      expect(_state(s.container).hasUnsavedChanges, isTrue);
    });

    test('updateNaipe sets any standard naipe and back to none (null)',
        () async {
      final s = _setUp(
        song: _song(lyrics: const [LyricLine(text: 'Ave', onsetMs: null)]),
      );
      addTearDown(s.container.dispose);
      await _settle(s.container);
      final notifier = _notifier(s.container);

      notifier.updateNaipe(0, Naipe.tenor);
      expect(_state(s.container).lines[0].naipe, Naipe.tenor);
      expect(_state(s.container).hasUnsavedChanges, isTrue);

      notifier.updateNaipe(0, null);
      expect(_state(s.container).lines[0].naipe, isNull);
    });

    test('updateDynamics accepts up to 40 chars, rejects 41, empty -> null',
        () async {
      final s = _setUp(
        song: _song(lyrics: const [LyricLine(text: 'Ave', onsetMs: null)]),
      );
      addTearDown(s.container.dispose);
      await _settle(s.container);
      final notifier = _notifier(s.container);

      notifier.updateDynamics(0, 'forte');
      expect(_state(s.container).lines[0].dynamics, 'forte');

      notifier.updateDynamics(0, 'x' * 41);
      expect(_state(s.container).lines[0].dynamics, 'forte');

      notifier.updateDynamics(0, 'x' * 40);
      expect(_state(s.container).lines[0].dynamics, 'x' * 40);

      notifier.updateDynamics(0, '');
      expect(_state(s.container).lines[0].dynamics, isNull);
    });

    test('setExpanded only changes the expanded line, never unsaved state',
        () async {
      final s = _setUp(
        song: _song(lyrics: const [LyricLine(text: 'Ave', onsetMs: null)]),
      );
      addTearDown(s.container.dispose);
      await _settle(s.container);

      _notifier(s.container).setExpanded(0);
      expect(_state(s.container).expandedIndex, 0);
      _notifier(s.container).setExpanded(null);
      expect(_state(s.container).expandedIndex, isNull);
      expect(_state(s.container).hasUnsavedChanges, isFalse);
    });
  });

  group('preview and pause (LYR-03, LYR-08, LYR-18)', () {
    test('togglePreview starts every track from 0 ms in marking mode',
        () async {
      final s = _setUp();
      addTearDown(s.container.dispose);
      await _settle(s.container);

      await _notifier(s.container).togglePreview();

      expect(s.engine.calls, ['load', 'seek:0', 'play']);
      expect(_state(s.container).previewing, isTrue);
      expect(_state(s.container).playing, isTrue);
    });

    test('togglePreview does nothing when the song has no tracks', () async {
      final s = _setUp(song: _song(tracks: const []));
      addTearDown(s.container.dispose);
      await _settle(s.container);

      await _notifier(s.container).togglePreview();

      expect(s.engine.calls, isEmpty);
      expect(_state(s.container).previewing, isFalse);
    });

    test('togglePreview sets previewError and stays off if loading fails',
        () async {
      final s = _setUp();
      addTearDown(s.container.dispose);
      await _settle(s.container);
      s.engine.throwOnLoad = true;

      await _notifier(s.container).togglePreview();

      expect(_state(s.container).previewError, isNotNull);
      expect(_state(s.container).previewing, isFalse);
      expect(s.engine.calls, isEmpty);
    });

    // Regression: the design made "Pausar" leave marking mode and restart
    // from 0 ms, contradicting spec AC9. Pause must keep marking mode and
    // resume where it stopped.
    test('togglePause pauses inside marking mode and resumes with no seek',
        () async {
      final s = _setUp();
      addTearDown(s.container.dispose);
      await _settle(s.container);
      await _previewAt(s.container, s.engine, 42000);
      final notifier = _notifier(s.container);

      await notifier.togglePause();
      expect(_state(s.container).previewing, isTrue);
      expect(_state(s.container).playing, isFalse);
      expect(s.engine.calls.last, 'pause');

      await notifier.togglePause();
      expect(_state(s.container).playing, isTrue);
      expect(s.engine.calls.last, 'play');
      expect(s.engine.seekAllToCalls, [0],
          reason: 'resuming must not seek back to 0 ms');
    });

    test('togglePreview while previewing leaves marking mode and stops audio',
        () async {
      final s = _setUp();
      addTearDown(s.container.dispose);
      await _settle(s.container);
      await _previewAt(s.container, s.engine, 1000);

      await _notifier(s.container).togglePreview();

      expect(_state(s.container).previewing, isFalse);
      expect(_state(s.container).playing, isFalse);
      expect(s.engine.calls.last, 'stop');
    });

    test('turning marking mode on again restarts from 0 ms without reloading',
        () async {
      final s = _setUp();
      addTearDown(s.container.dispose);
      await _settle(s.container);
      await _previewAt(s.container, s.engine, 1000);
      await _notifier(s.container).togglePreview();

      await _notifier(s.container).togglePreview();

      expect(s.engine.seekAllToCalls, [0, 0]);
      expect(s.engine.loadCount, 1);
    });
  });

  group('markNow (LYR-05, LYR-06, LYR-07)', () {
    test('marks the next unmarked line at the current time and advances',
        () async {
      final s = _setUp(
        song: _song(lyrics: const [
          LyricLine(text: 'Ave verum corpus', onsetMs: 1000),
          LyricLine(text: 'natum de Maria Virgine', onsetMs: null),
          LyricLine(text: 'vere passum immolatum', onsetMs: null),
        ]),
      );
      addTearDown(s.container.dispose);
      await _settle(s.container);
      await _previewAt(s.container, s.engine, 5300);
      expect(_state(s.container).nextUnmarkedIndex, 1);

      _notifier(s.container).markNow();

      final state = _state(s.container);
      expect(state.lines[1].onsetMs, 5300);
      expect(state.lines[2].onsetMs, isNull);
      expect(state.nextUnmarkedIndex, 2);
      expect(state.markError, isNull);
      expect(state.hasUnsavedChanges, isTrue);
    });

    test('rejects a mark earlier than the previous marked line, no change',
        () async {
      final s = _setUp(
        song: _song(lyrics: const [
          LyricLine(text: 'Ave verum corpus', onsetMs: 8000),
          LyricLine(text: 'natum de Maria Virgine', onsetMs: null),
        ]),
      );
      addTearDown(s.container.dispose);
      await _settle(s.container);
      await _previewAt(s.container, s.engine, 7999);

      _notifier(s.container).markNow();

      final state = _state(s.container);
      expect(state.markError, isNotNull);
      expect(state.lines[1].onsetMs, isNull);
      expect(state.nextUnmarkedIndex, 1);
      expect(state.hasUnsavedChanges, isFalse);
    });

    // Regression (sensor M2): AC7 rejects only an instant *earlier* than
    // the previous line, so the same instant must be accepted.
    test('accepts a mark at exactly the previous marked line\'s instant',
        () async {
      final s = _setUp(
        song: _song(lyrics: const [
          LyricLine(text: 'Ave verum corpus', onsetMs: 8000),
          LyricLine(text: 'natum de Maria Virgine', onsetMs: null),
        ]),
      );
      addTearDown(s.container.dispose);
      await _settle(s.container);
      await _previewAt(s.container, s.engine, 8000);

      _notifier(s.container).markNow();

      final state = _state(s.container);
      expect(state.markError, isNull);
      expect(state.lines[1].onsetMs, 8000);
      expect(state.nextUnmarkedIndex, isNull);
    });

    test('compares against the nearest marked line before, skipping gaps',
        () async {
      final s = _setUp(
        song: _song(lyrics: const [
          LyricLine(text: 'Ave verum corpus', onsetMs: 9000),
          LyricLine(text: 'natum de Maria Virgine', onsetMs: 2000),
          LyricLine(text: 'vere passum immolatum', onsetMs: null),
        ]),
      );
      addTearDown(s.container.dispose);
      await _settle(s.container);
      await _previewAt(s.container, s.engine, 3000);

      _notifier(s.container).markNow();

      expect(_state(s.container).lines[2].onsetMs, 3000,
          reason: 'only the immediately previous marked line (2000) counts');
    });

    test('does nothing when every line is already marked', () async {
      final s = _setUp(
        song: _song(lyrics: const [LyricLine(text: 'Ave', onsetMs: 1000)]),
      );
      addTearDown(s.container.dispose);
      await _settle(s.container);
      await _previewAt(s.container, s.engine, 4000);

      _notifier(s.container).markNow();

      final state = _state(s.container);
      expect(state.nextUnmarkedIndex, isNull);
      expect(state.lines.single.onsetMs, 1000);
      expect(state.hasUnsavedChanges, isFalse);
    });

    test('does nothing while paused (marking only during playback)', () async {
      final s = _setUp(
        song: _song(lyrics: const [LyricLine(text: 'Ave', onsetMs: null)]),
      );
      addTearDown(s.container.dispose);
      await _settle(s.container);
      await _previewAt(s.container, s.engine, 4000);
      await _notifier(s.container).togglePause();

      _notifier(s.container).markNow();

      expect(_state(s.container).lines.single.onsetMs, isNull);
    });
  });

  group('derived values (LYR-10, LYR-13)', () {
    test('markedCount counts lines with a time; nextUnmarkedIndex is first',
        () async {
      final s = _setUp(
        song: _song(lyrics: const [
          LyricLine(text: 'a', onsetMs: 0),
          LyricLine(text: 'b', onsetMs: null),
          LyricLine(text: 'c', onsetMs: 3000),
          LyricLine(text: 'd', onsetMs: null),
        ]),
      );
      addTearDown(s.container.dispose);
      await _settle(s.container);

      final state = _state(s.container);
      expect(state.markedCount, 2);
      expect(state.nextUnmarkedIndex, 1);
    });

    test('currentLineIndex is the marked line with greatest onset <= now',
        () async {
      final s = _setUp(
        song: _song(lyrics: const [
          LyricLine(text: 'a', onsetMs: 1000),
          LyricLine(text: 'b', onsetMs: null),
          LyricLine(text: 'c', onsetMs: 4000),
        ]),
      );
      addTearDown(s.container.dispose);
      await _settle(s.container);

      await _previewAt(s.container, s.engine, 999);
      expect(_state(s.container).currentLineIndex, isNull);

      s.engine.emitPosition(1000);
      await _flush();
      expect(_state(s.container).currentLineIndex, 0);

      s.engine.emitPosition(3999);
      await _flush();
      expect(_state(s.container).currentLineIndex, 0);

      s.engine.emitPosition(4000);
      await _flush();
      expect(_state(s.container).currentLineIndex, 2);
    });
  });

  group('save (LYR-11, LYR-22)', () {
    test('persists lines with text in order, drops still-empty drafts',
        () async {
      final s = _setUp(
        song: _song(lyrics: const [
          LyricLine(text: 'Ave verum corpus', onsetMs: 1000),
        ]),
      );
      addTearDown(s.container.dispose);
      await _settle(s.container);
      final notifier = _notifier(s.container);
      notifier.addLine();
      notifier.updateText(1, 'natum de Maria Virgine');
      notifier.updateNaipe(1, Naipe.contralto);
      notifier.updateDynamics(1, 'piano');
      notifier.addLine(); // never filled in

      await notifier.save();
      await _flush();

      final saved = s.repo.savedSong!.lyrics;
      expect(saved.map((l) => l.text).toList(),
          ['Ave verum corpus', 'natum de Maria Virgine']);
      expect(saved[0].onsetMs, 1000);
      expect(saved[1].onsetMs, isNull);
      expect(saved[1].naipe, Naipe.contralto);
      expect(saved[1].dynamics, 'piano');
      expect(_state(s.container).hasUnsavedChanges, isFalse);
      expect(_state(s.container).saveError, isNull);
    });

    test('success re-fetches the song so the screen shows what was stored',
        () async {
      final s = _setUp();
      addTearDown(s.container.dispose);
      await _settle(s.container);
      final fetchesBefore = s.repo.getByIdCount;
      _notifier(s.container).addLine();
      _notifier(s.container).updateText(0, 'Ave');
      _notifier(s.container).addLine();

      await _notifier(s.container).save();
      await s.container.read(songByIdProvider('ave').future);
      await _flush();

      expect(s.repo.getByIdCount, fetchesBefore + 1);
      expect(_state(s.container).lines.map((l) => l.text).toList(), ['Ave']);
    });

    // Regression: while re-fetching after save, Riverpod hands the listener
    // the previous (pre-save) song, and the notifier briefly replaced the
    // edited lines with the old lyrics (a flash of stale text on screen).
    test('re-fetch after save never shows the pre-save lyrics', () async {
      final s = _setUp(
        song: _song(lyrics: const [
          LyricLine(text: 'Ave verum corpus', onsetMs: 1000),
        ]),
      );
      addTearDown(s.container.dispose);
      await _settle(s.container);
      _notifier(s.container).addLine();
      _notifier(s.container).updateText(1, 'natum de Maria Virgine');

      final seen = <List<String>>[];
      s.container.listen<LyricsEditorState>(
        lyricsEditorProvider('ave'),
        (_, next) => seen.add(next.lines.map((l) => l.text).toList()),
      );
      await _notifier(s.container).save();
      await s.container.read(songByIdProvider('ave').future);
      await _flush();

      expect(seen, isNot(contains(equals(['Ave verum corpus']))));
      expect(seen.last, ['Ave verum corpus', 'natum de Maria Virgine']);
    });

    test('failure keeps every edit and unsaved state, sets saveError',
        () async {
      final s = _setUp();
      addTearDown(s.container.dispose);
      await _settle(s.container);
      s.repo.saveResult = Result.failure(StorageFailure(code: 'disk_full'));
      _notifier(s.container).addLine();
      _notifier(s.container).updateText(0, 'Ave');

      await _notifier(s.container).save();

      final state = _state(s.container);
      expect(state.saveError, isNotNull);
      expect(state.saving, isFalse);
      expect(state.hasUnsavedChanges, isTrue);
      expect(state.lines.map((l) => l.text).toList(), ['Ave']);
    });
  });

  group('leaving the screen (LYR-21)', () {
    test('disposing the provider stops audio started by the preview', () async {
      final s = _setUp();
      addTearDown(s.container.dispose);
      final sub = s.container.listen(lyricsEditorProvider('ave'), (_, __) {});
      await s.container.read(songByIdProvider('ave').future);
      await _flush();
      await _notifier(s.container).togglePreview();

      sub.close();
      await _flush();

      expect(s.engine.calls.last, 'stop');
    });
  });
}
