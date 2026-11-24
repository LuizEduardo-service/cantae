import 'dart:io';

import 'package:cantae/infrastructure/database/app_database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as raw_sqlite3;

void main() {
  group('AppDatabase migration v1 -> v2 (LIB-12)', () {
    test(
        'upgrading from schema v1 preserves an existing row and backfills origin/lastRehearsedAt',
        () async {
      final dir = Directory.systemTemp.createTempSync('cantae_migration_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final dbPath = p.join(dir.path, 'legacy.db');

      final raw = raw_sqlite3.sqlite3.open(dbPath);
      raw.execute('''
        CREATE TABLE songs (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          author TEXT NOT NULL,
          version TEXT NOT NULL,
          metronome_bpm INTEGER NULL,
          metronome_beats_per_measure INTEGER NULL,
          metronome_downbeat_accent INTEGER NULL,
          metronome_enabled_by_default INTEGER NULL
        );
      ''');
      // A real v1 database always has lyric_lines (created since Phase 2),
      // and later migration steps (v2 -> v3) rebuild it.
      raw.execute('''
        CREATE TABLE lyric_lines (
          row_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          song_id TEXT NOT NULL REFERENCES songs (id) ON DELETE CASCADE,
          text TEXT NOT NULL,
          onset_ms INTEGER NOT NULL,
          naipe TEXT NULL,
          dynamics TEXT NULL
        );
      ''');
      raw.execute(
        "INSERT INTO songs (id, name, author, version) VALUES ('legacy-1', 'Legacy Song', 'Legacy Author', '')",
      );
      raw.execute('PRAGMA user_version = 1;');
      raw.close();

      final db = AppDatabase(NativeDatabase(File(dbPath)));
      addTearDown(db.close);

      final row = await (db.select(db.songsTable)
            ..where((s) => s.id.equals('legacy-1')))
          .getSingle();

      expect(row.name, equals('Legacy Song'));
      expect(row.author, equals('Legacy Author'));
      expect(row.origin, equals('created'));
      expect(row.lastRehearsedAt, isNull);
    });

    test(
        'a fresh v2 install creates the origin/lastRehearsedAt columns directly via onCreate',
        () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final columns = await db.customSelect("PRAGMA table_info('songs')").get();
      final columnNames = columns.map((r) => r.data['name'] as String).toSet();

      expect(columnNames, containsAll(<String>['origin', 'last_rehearsed_at']));
    });
  });

  group('AppDatabase migration v2 -> v3 (LYR-01/LYR-02: nullable onset_ms)',
      () {
    test(
        'upgrading from schema v2 preserves an existing lyric_lines row unchanged',
        () async {
      final dbPath = _seedV2Database();

      final db = AppDatabase(NativeDatabase(File(dbPath)));
      addTearDown(db.close);

      final rows = await (db.select(db.lyricLinesTable)
            ..where((l) => l.songId.equals('ave-1')))
          .get();

      expect(rows, hasLength(1));
      expect(rows.single.lyricText, equals('Ave verum corpus'));
      expect(rows.single.onsetMs, equals(12500));
      expect(rows.single.naipe, equals('soprano'));
      expect(rows.single.dynamics, equals('piano'));
    });

    // Regression (sensor M14): the test above passes even without the
    // alterTable step, so it never proved an upgraded device can store an
    // unmarked line. Without the step, onset_ms stays NOT NULL there and
    // saving any unmarked line fails.
    test('an upgraded v2 database accepts a lyric_lines row with onsetMs null',
        () async {
      final dbPath = _seedV2Database();

      final db = AppDatabase(NativeDatabase(File(dbPath)));
      addTearDown(db.close);

      await db.into(db.lyricLinesTable).insert(
            const LyricLinesTableCompanion(
              songId: Value('ave-1'),
              lyricText: Value('natum de Maria Virgine'),
              onsetMs: Value(null),
            ),
          );

      final rows = await (db.select(db.lyricLinesTable)
            ..where((l) => l.songId.equals('ave-1'))
            ..orderBy([(l) => OrderingTerm.asc(l.rowId)]))
          .get();
      expect(rows.map((r) => r.lyricText).toList(),
          ['Ave verum corpus', 'natum de Maria Virgine']);
      expect(rows.map((r) => r.onsetMs).toList(), [12500, isNull]);
    });

    test('a fresh v3 install accepts a lyric_lines row with onsetMs null',
        () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await db.into(db.songsTable).insert(
            SongsTableCompanion.insert(
              id: 'ave-1',
              name: 'Ave Verum Corpus',
              author: 'Mozart',
              version: '',
            ),
          );
      await db.into(db.lyricLinesTable).insert(
            const LyricLinesTableCompanion(
              songId: Value('ave-1'),
              lyricText: Value('Ave verum corpus'),
              onsetMs: Value(null),
            ),
          );

      final row = await db.select(db.lyricLinesTable).getSingle();
      expect(row.lyricText, equals('Ave verum corpus'));
      expect(row.onsetMs, isNull);
    });
  });
}

/// A schema-v2 database file: `onset_ms` is still NOT NULL, with one song
/// (`ave-1`) and one marked lyric line. Deleted after the test.
String _seedV2Database() {
  final dir = Directory.systemTemp.createTempSync('cantae_migration_v3_test');
  addTearDown(() => dir.deleteSync(recursive: true));
  final dbPath = p.join(dir.path, 'v2.db');

  final raw = raw_sqlite3.sqlite3.open(dbPath);
  raw.execute('''
    CREATE TABLE songs (
      id TEXT NOT NULL PRIMARY KEY,
      name TEXT NOT NULL,
      author TEXT NOT NULL,
      version TEXT NOT NULL,
      metronome_bpm INTEGER NULL,
      metronome_beats_per_measure INTEGER NULL,
      metronome_downbeat_accent INTEGER NULL,
      metronome_enabled_by_default INTEGER NULL,
      origin TEXT NOT NULL DEFAULT 'created',
      last_rehearsed_at INTEGER NULL
    );
  ''');
  raw.execute('''
    CREATE TABLE lyric_lines (
      row_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      song_id TEXT NOT NULL REFERENCES songs (id) ON DELETE CASCADE,
      text TEXT NOT NULL,
      onset_ms INTEGER NOT NULL,
      naipe TEXT NULL,
      dynamics TEXT NULL
    );
  ''');
  raw.execute(
    "INSERT INTO songs (id, name, author, version) VALUES ('ave-1', 'Ave Verum Corpus', 'Mozart', '')",
  );
  raw.execute(
    'INSERT INTO lyric_lines (song_id, text, onset_ms, naipe, dynamics) '
    "VALUES ('ave-1', 'Ave verum corpus', 12500, 'soprano', 'piano')",
  );
  raw.execute('PRAGMA user_version = 2;');
  raw.close();
  return dbPath;
}
