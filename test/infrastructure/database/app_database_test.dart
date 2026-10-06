import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:cantae/infrastructure/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('AppDatabase schema (v1)', () {
    test('creates songs, song_tracks, and lyric_lines tables', () async {
      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table'",
          )
          .get();
      final tableNames = rows.map((r) => r.data['name'] as String).toSet();

      expect(tableNames, containsAll(<String>['songs', 'song_tracks', 'lyric_lines']));
    });

    test('rejects a duplicate songs.id (TEXT PRIMARY KEY enforced)', () async {
      await db.customStatement(
        "INSERT INTO songs (id, name, author, version) VALUES ('dup', 'A', 'Author', '')",
      );

      expect(
        () => db.customStatement(
          "INSERT INTO songs (id, name, author, version) VALUES ('dup', 'B', 'Author', '')",
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects a duplicate song_tracks.id (TEXT PRIMARY KEY enforced)', () async {
      await db.customStatement(
        "INSERT INTO songs (id, name, author, version) VALUES ('s1', 'A', 'Author', '')",
      );
      await db.customStatement(
        'INSERT INTO song_tracks (id, song_id, file_path, naipe, start_delay_ms, is_playback, is_playback_slot) '
        "VALUES ('dup', 's1', 'a.mp3', 'soprano', 0, 0, 0)",
      );

      expect(
        () => db.customStatement(
          'INSERT INTO song_tracks (id, song_id, file_path, naipe, start_delay_ms, is_playback, is_playback_slot) '
          "VALUES ('dup', 's1', 'b.mp3', 'tenor', 0, 0, 0)",
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('enables foreign key enforcement', () async {
      final result = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(result.data['foreign_keys'], equals(1));
    });
  });

  group('AppDatabase cascade delete (LIB-02)', () {
    test('deleting a song row cascades to its song_tracks row', () async {
      await db.customStatement(
        "INSERT INTO songs (id, name, author, version) VALUES ('s1', 'Song', 'Author', '')",
      );
      await db.customStatement(
        'INSERT INTO song_tracks (id, song_id, file_path, naipe, start_delay_ms, is_playback, is_playback_slot) '
        "VALUES ('t1', 's1', 'a.mp3', 'soprano', 0, 0, 0)",
      );

      final before = await db.customSelect('SELECT * FROM song_tracks WHERE song_id = ?',
              variables: [Variable.withString('s1')])
          .get();
      expect(before, hasLength(1));

      await db.customStatement("DELETE FROM songs WHERE id = 's1'");

      final after = await db.customSelect('SELECT * FROM song_tracks WHERE song_id = ?',
              variables: [Variable.withString('s1')])
          .get();
      expect(after, isEmpty);
    });
  });
}
