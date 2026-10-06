import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:cantae/data/repositories/drift_song_repository.dart';
import 'package:cantae/domain/entities/lyric_line.dart';
import 'package:cantae/domain/entities/metronome_config.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/entities/song_track.dart';
import 'package:cantae/infrastructure/database/app_database.dart';

void main() {
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
        tracks: const [
          SongTrack(id: 'track-s', filePath: 'soprano.mp3', naipe: Naipe.soprano),
          SongTrack(id: 'track-c', filePath: 'contralto.mp3', naipe: Naipe.contralto),
        ],
        playbackTrack: const SongTrack(
          id: 'track-pb',
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
  });
}
