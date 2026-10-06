import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:cantae/data/repositories/drift_song_repository.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/entities/lyric_line.dart';
import 'package:cantae/domain/entities/metronome_config.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/entities/song_track.dart';
import 'package:cantae/infrastructure/database/app_database.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late DriftSongRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftSongRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Song fixtureSong({String id = 'song-1'}) => Song(
        id: id,
        name: 'Complete Song',
        author: 'Fixture Author',
        version: '1.0',
        tracks: [
          SongTrack(id: 'track-s-$id', filePath: 'soprano.mp3', naipe: Naipe.soprano),
          SongTrack(id: 'track-c-$id', filePath: 'contralto.mp3', naipe: Naipe.contralto),
        ],
        playbackTrack: SongTrack(
          id: 'track-pb-$id',
          filePath: 'playback.mp3',
          naipe: Naipe.custom,
          isPlayback: true,
        ),
        lyrics: const [
          LyricLine(text: 'First line', onsetMs: 1000, naipe: Naipe.soprano),
          LyricLine(text: 'Second line', onsetMs: 3500, naipe: Naipe.soprano),
          LyricLine(text: 'Third line', onsetMs: 6200, naipe: Naipe.soprano),
        ],
        metronomeConfig: const MetronomeConfig(bpm: 100, beatsPerMeasure: 4),
      );

  group('DriftSongRepository.save', () {
    test('inserts a new song with tracks, playback track, and lyrics (LIB-06)', () async {
      final result = await repo.save(fixtureSong());

      expect(result.isSuccess, isTrue);

      final songRows = await db.select(db.songsTable).get();
      final trackRows = await db.select(db.songTracksTable).get();
      final lyricRows = await db.select(db.lyricLinesTable).get();

      expect(songRows, hasLength(1));
      expect(trackRows, hasLength(3));
      expect(lyricRows, hasLength(3));
    });

    test('upsert fully replaces existing tracks/lyrics, leaving no leftover rows (LIB-07)',
        () async {
      await repo.save(fixtureSong());

      const replacement = Song(
        id: 'song-1',
        name: 'Renamed Song',
        author: 'Fixture Author',
        tracks: [
          SongTrack(id: 'new-track', filePath: 'new.mp3', naipe: Naipe.bass),
        ],
      );
      final result = await repo.save(replacement);

      expect(result.isSuccess, isTrue);

      final songRows = await db.select(db.songsTable).get();
      final trackRows = await db.select(db.songTracksTable).get();
      final lyricRows = await db.select(db.lyricLinesTable).get();

      expect(songRows, hasLength(1));
      expect(songRows.single.name, equals('Renamed Song'));
      expect(trackRows, hasLength(1));
      expect(trackRows.single.id, equals('new-track'));
      expect(lyricRows, isEmpty);
    });

    test('rolls back the whole transaction and returns StorageFailure on write failure (LIB-08, LIB-09)',
        () async {
      // Two tracks sharing the same id violate song_tracks' TEXT PRIMARY KEY,
      // forcing a real write failure partway through the transaction.
      const songWithDuplicateTrackIds = Song(
        id: 'song-fail',
        name: 'Will Fail',
        author: 'Author',
        tracks: [
          SongTrack(id: 'dup', filePath: 'a.mp3', naipe: Naipe.soprano),
          SongTrack(id: 'dup', filePath: 'b.mp3', naipe: Naipe.tenor),
        ],
      );

      final result = await repo.save(songWithDuplicateTrackIds);

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) => expect(f.code, isNotEmpty),
      );

      final songRows = await (db.select(db.songsTable)
            ..where((s) => s.id.equals('song-fail')))
          .get();
      expect(songRows, isEmpty, reason: 'the song insert must roll back with the failed track insert');
    });

    test('saves successfully when metronomeConfig is null, without throwing (LIB-10)', () async {
      const song = Song(id: 'song-null-metronome', name: 'No Metronome', author: 'Author');

      final result = await repo.save(song);

      expect(result.isSuccess, isTrue);
      final songRows = await db.select(db.songsTable).get();
      expect(songRows.single.metronomeBpm, isNull);
    });

    test('persists no is_playback_slot = 1 row when playbackTrack is null', () async {
      const song = Song(
        id: 'song-no-playback',
        name: 'No Playback Track',
        author: 'Author',
        tracks: [
          SongTrack(id: 'track-only', filePath: 'only.mp3', naipe: Naipe.soprano),
        ],
      );

      final result = await repo.save(song);

      expect(result.isSuccess, isTrue);
      final trackRows = await db.select(db.songTracksTable).get();
      expect(trackRows, hasLength(1));
      expect(trackRows.every((row) => !row.isPlaybackSlot), isTrue,
          reason: 'no row should be marked as the playback slot');
    });
  });

  group('DriftSongRepository.getById', () {
    test('returns every field exactly equal to what was saved (LIB-11)', () async {
      final fixture = fixtureSong();
      await repo.save(fixture);

      final result = await repo.getById('song-1');

      expect(result.isSuccess, isTrue);
      result.when(
        success: (song) {
          expect(song.id, equals(fixture.id));
          expect(song.name, equals(fixture.name));
          expect(song.author, equals(fixture.author));
          expect(song.version, equals(fixture.version));

          expect(song.tracks, hasLength(2));
          final trackIds = song.tracks.map((t) => t.id).toSet();
          expect(trackIds, equals({'track-s-song-1', 'track-c-song-1'}));
          final soprano = song.tracks.firstWhere((t) => t.id == 'track-s-song-1');
          expect(soprano.filePath, equals('soprano.mp3'));
          expect(soprano.naipe, equals(Naipe.soprano));

          expect(song.playbackTrack, isNotNull);
          expect(song.playbackTrack!.id, equals('track-pb-song-1'));
          expect(song.playbackTrack!.isPlayback, isTrue);

          expect(song.lyrics, hasLength(3));
          expect(song.lyrics.map((l) => l.text).toList(), [
            'First line',
            'Second line',
            'Third line',
          ]);

          expect(song.metronomeConfig, isNotNull);
          expect(song.metronomeConfig!.bpm, equals(100));
          expect(song.metronomeConfig!.beatsPerMeasure, equals(4));
        },
        failure: (_) => fail('expected success'),
      );
    });

    test('returns NotFoundFailure for an unknown id (LIB-12)', () async {
      final result = await repo.getById('does-not-exist');

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) {
          expect(f, isA<NotFoundFailure>());
          expect(f.code, isNotEmpty);
        },
      );
    });
  });

  group('DriftSongRepository.getAll', () {
    test('returns exactly N songs for N saved songs (LIB-13)', () async {
      await repo.save(fixtureSong());
      await repo.save(fixtureSong(id: 'song-2'));
      await repo.save(fixtureSong(id: 'song-3'));

      final result = await repo.getAll();

      expect(result.isSuccess, isTrue);
      result.when(
        success: (songs) => expect(songs, hasLength(3)),
        failure: (_) => fail('expected success'),
      );
    });

    test('returns an empty list (not a failure) for an empty library (LIB-14)', () async {
      final result = await repo.getAll();

      expect(result.isSuccess, isTrue);
      result.when(
        success: (songs) => expect(songs, isEmpty),
        failure: (_) => fail('expected success'),
      );
    });

    test('orders each song\'s lyrics by ascending onsetMs, stable on ties (LIB-15)', () async {
      const song = Song(
        id: 'song-ties',
        name: 'Tied Lyrics',
        author: 'Author',
        lyrics: [
          LyricLine(text: 'third (tie)', onsetMs: 1000),
          LyricLine(text: 'first', onsetMs: 500),
          LyricLine(text: 'second (tie)', onsetMs: 1000),
        ],
      );
      await repo.save(song);

      final firstRead = await repo.getAll();
      final secondRead = await repo.getAll();

      List<String> textsOf(Result<List<Song>, StorageFailure> result) => result.when(
            success: (songs) => songs.single.lyrics.map((l) => l.text).toList(),
            failure: (_) => throw StateError('expected success'),
          );

      final expectedOrder = ['first', 'third (tie)', 'second (tie)'];
      expect(textsOf(firstRead), equals(expectedOrder));
      expect(textsOf(secondRead), equals(expectedOrder),
          reason: 'tie-break order must be stable across repeated calls');
    });

    test('issues a bounded number of queries independent of song count (no N+1)', () async {
      final counter = _QueryCountInterceptor();
      final countedDb = AppDatabase(NativeDatabase.memory().interceptWith(counter));
      final countedRepo = DriftSongRepository(countedDb);
      addTearDown(countedDb.close);

      for (var i = 0; i < 5; i++) {
        await countedRepo.save(fixtureSong(id: 'song-$i'));
      }

      counter.selectCount = 0;
      final result = await countedRepo.getAll();

      expect(result.isSuccess, isTrue);
      result.when(success: (songs) => expect(songs, hasLength(5)), failure: (_) => fail('expected success'));
      expect(counter.selectCount, equals(3),
          reason: 'getAll() must issue exactly 3 SELECTs (songs, tracks, lyrics) regardless of song count');
    });
  });

  group('DriftSongRepository.delete', () {
    test('removes the song row and cascades its tracks/lyrics (LIB-16, LIB-18)', () async {
      await repo.save(fixtureSong());

      final result = await repo.delete('song-1');

      expect(result.isSuccess, isTrue);

      final songRows = await (db.select(db.songsTable)..where((s) => s.id.equals('song-1'))).get();
      final trackRows = await (db.select(db.songTracksTable)
            ..where((t) => t.songId.equals('song-1')))
          .get();
      final lyricRows = await (db.select(db.lyricLinesTable)
            ..where((l) => l.songId.equals('song-1')))
          .get();

      expect(songRows, isEmpty);
      expect(trackRows, isEmpty);
      expect(lyricRows, isEmpty);

      final allResult = await repo.getAll();
      allResult.when(
        success: (songs) => expect(songs.any((s) => s.id == 'song-1'), isFalse),
        failure: (_) => fail('expected success'),
      );
    });

    test('returns NotFoundFailure for an unknown id, touching no rows (LIB-17)', () async {
      await repo.save(fixtureSong());

      final result = await repo.delete('does-not-exist');

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) {
          expect(f, isA<NotFoundFailure>());
          expect(f.code, isNotEmpty);
        },
      );

      final songRows = await db.select(db.songsTable).get();
      expect(songRows, hasLength(1), reason: 'the existing song must be untouched');
    });
  });

  group('DriftSongRepository.deleteAll', () {
    test('removes every song, track, and lyric row (LIB-19)', () async {
      await repo.save(fixtureSong());
      await repo.save(fixtureSong(id: 'song-2'));
      await repo.save(fixtureSong(id: 'song-3'));

      final result = await repo.deleteAll();

      expect(result.isSuccess, isTrue);

      final allResult = await repo.getAll();
      allResult.when(
        success: (songs) => expect(songs, isEmpty),
        failure: (_) => fail('expected success'),
      );
      expect(await db.select(db.songTracksTable).get(), isEmpty);
      expect(await db.select(db.lyricLinesTable).get(), isEmpty);
    });

    test('returns Result.success(Unit) on an already-empty library (LIB-20)', () async {
      final result = await repo.deleteAll();

      expect(result.isSuccess, isTrue);
    });
  });
}

class _QueryCountInterceptor extends QueryInterceptor {
  int selectCount = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    selectCount++;
    return executor.runSelect(statement, args);
  }
}
