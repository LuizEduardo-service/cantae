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
      // song_tracks exists since Phase 2 (schema v1); the v5 step adds
      // columns to it.
      raw.execute('''
        CREATE TABLE song_tracks (
          id TEXT NOT NULL PRIMARY KEY,
          song_id TEXT NOT NULL REFERENCES songs (id) ON DELETE CASCADE,
          file_path TEXT NOT NULL,
          naipe TEXT NOT NULL,
          start_delay_ms INTEGER NOT NULL,
          is_playback INTEGER NOT NULL,
          is_playback_slot INTEGER NOT NULL DEFAULT 0
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
  // Failure modes (HIST-18, schema v4): upgrading a v3 library loses songs;
  // the rehearsal_logs table is missing after an upgrade or a fresh
  // install; deleting a song leaves its rehearsals behind.
  group('AppDatabase migration v3 -> v4 (rehearsal_logs)', () {
    test('a v3 library upgrades with its song intact and the new table',
        () async {
      final db = AppDatabase(NativeDatabase(File(_seedV3Database())));
      addTearDown(db.close);

      final song = await db.select(db.songsTable).getSingle();
      expect(song.id, 'ave-1');
      expect(song.name, 'Ave Verum Corpus');
      expect(await _columnsOf(db, 'rehearsal_logs'), _rehearsalColumns);
    });

    test('a fresh install creates rehearsal_logs', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      expect(await _columnsOf(db, 'rehearsal_logs'), _rehearsalColumns);
    });

    test('deleting a song deletes its rehearsals', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      for (final id in ['ave-1', 'aleluia']) {
        await db.into(db.songsTable).insert(SongsTableCompanion.insert(
              id: id,
              name: id,
              author: 'Mozart',
              version: '',
            ));
        await db.into(db.rehearsalLogsTable).insert(
              RehearsalLogsTableCompanion.insert(
                id: 'log-$id',
                songId: id,
                startedAt: DateTime(2026, 11, 25, 19),
                endedAt: DateTime(2026, 11, 25, 19, 15),
                durationMs: 750000,
                mode: 'solo',
                maxParticipants: 1,
                loopCount: 8,
              ),
            );
      }

      await (db.delete(db.songsTable)..where((s) => s.id.equals('ave-1'))).go();

      final left = await db.select(db.rehearsalLogsTable).get();
      expect(left.map((r) => r.songId), ['aleluia']);
    });
  });
  // Failure modes (UPL-15, UPL-19, schema v5): upgrading a v4 library loses
  // songs, tracks or rehearsals; old tracks get non-null values in the new
  // columns; custom_naipes is missing after an upgrade or a fresh install;
  // two custom naipes with the same name (any case) are stored.
  group('AppDatabase migration v4 -> v5 (custom naipes)', () {
    test('a v4 library upgrades with its song, track and rehearsal intact',
        () async {
      final db = AppDatabase(NativeDatabase(File(_seedV4Database())));
      addTearDown(db.close);

      final song = await db.select(db.songsTable).getSingle();
      expect(song.id, 'ave-1');
      final track = await db.select(db.songTracksTable).getSingle();
      expect(track.id, 't-sop');
      expect(track.startDelayMs, 400);
      expect(track.customNaipeId, isNull);
      expect(track.fileName, isNull);
      expect(track.fileSizeBytes, isNull);
      final logs = await db.select(db.rehearsalLogsTable).get();
      expect(logs.map((l) => l.id), ['log-1']);
      expect(await _columnsOf(db, 'custom_naipes'), _customNaipeColumns);
      expect(
        await _columnsOf(db, 'song_tracks'),
        containsAll(['custom_naipe_id', 'file_name', 'file_size_bytes']),
      );
    });

    test('a fresh install creates custom_naipes and the track columns',
        () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      expect(await _columnsOf(db, 'custom_naipes'), _customNaipeColumns);
      expect(
        await _columnsOf(db, 'song_tracks'),
        containsAll(['custom_naipe_id', 'file_name', 'file_size_bytes']),
      );
    });

    test('a second custom naipe with the same name key is refused', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.into(db.customNaipesTable).insert(
            CustomNaipesTableCompanion.insert(
              id: 'n1',
              name: 'Solista',
              nameKey: 'solista',
            ),
          );

      expect(
        () => db.into(db.customNaipesTable).insert(
              CustomNaipesTableCompanion.insert(
                id: 'n2',
                name: 'SOLISTA',
                nameKey: 'solista',
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  // Failure modes (ROOM-03, ROOM-48, schema v6): upgrading a v5 library
  // loses songs, tracks, custom naipes or rehearsals; local_profile is
  // missing after an upgrade or a fresh install.
  group('AppDatabase migration v5 -> v6 (local profile)', () {
    test('a v5 library upgrades intact, with an empty local_profile', () async {
      final db = AppDatabase(NativeDatabase(File(_seedV5Database())));
      addTearDown(db.close);

      expect((await db.select(db.songsTable).getSingle()).id, 'ave-1');
      final track = await db.select(db.songTracksTable).getSingle();
      expect(track.id, 't-sop');
      expect(track.customNaipeId, 'n-solista');
      expect(
          (await db.select(db.customNaipesTable).getSingle()).name, 'Solista');
      expect((await db.select(db.rehearsalLogsTable).get()).map((l) => l.id),
          ['log-1']);
      expect(await _columnsOf(db, 'local_profile'), _localProfileColumns);
      expect(await db.select(db.localProfileTable).get(), isEmpty);
    });

    test('a fresh install creates local_profile', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      expect(await _columnsOf(db, 'local_profile'), _localProfileColumns);
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
  // song_tracks exists since Phase 2 (schema v1); the v5 step adds columns
  // to it.
  raw.execute('''
    CREATE TABLE song_tracks (
      id TEXT NOT NULL PRIMARY KEY,
      song_id TEXT NOT NULL REFERENCES songs (id) ON DELETE CASCADE,
      file_path TEXT NOT NULL,
      naipe TEXT NOT NULL,
      start_delay_ms INTEGER NOT NULL,
      is_playback INTEGER NOT NULL,
      is_playback_slot INTEGER NOT NULL DEFAULT 0
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

const _rehearsalColumns = {
  'id',
  'song_id',
  'started_at',
  'ended_at',
  'duration_ms',
  'mode',
  'local_role',
  'max_participants',
  'loop_count',
};

Future<Set<String>> _columnsOf(AppDatabase db, String table) async {
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return rows.map((r) => r.data['name'] as String).toSet();
}

/// A schema-v3 database file with one song (`ave-1`). Deleted after the
/// test.
String _seedV3Database() {
  final dir = Directory.systemTemp.createTempSync('cantae_migration_v4_test');
  addTearDown(() => dir.deleteSync(recursive: true));
  final dbPath = p.join(dir.path, 'v3.db');

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
    CREATE TABLE song_tracks (
      id TEXT NOT NULL PRIMARY KEY,
      song_id TEXT NOT NULL REFERENCES songs (id) ON DELETE CASCADE,
      file_path TEXT NOT NULL,
      naipe TEXT NOT NULL,
      start_delay_ms INTEGER NOT NULL,
      is_playback INTEGER NOT NULL,
      is_playback_slot INTEGER NOT NULL DEFAULT 0
    );
  ''');
  raw.execute('''
    CREATE TABLE lyric_lines (
      row_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      song_id TEXT NOT NULL REFERENCES songs (id) ON DELETE CASCADE,
      text TEXT NOT NULL,
      onset_ms INTEGER NULL,
      naipe TEXT NULL,
      dynamics TEXT NULL
    );
  ''');
  raw.execute(
    "INSERT INTO songs (id, name, author, version) VALUES ('ave-1', 'Ave Verum Corpus', 'Mozart', '')",
  );
  raw.execute('PRAGMA user_version = 3;');
  raw.close();
  return dbPath;
}

const _customNaipeColumns = {'id', 'name', 'name_key'};

/// A schema-v4 database file: the v3 library plus `rehearsal_logs`, one
/// Soprano track (delay 400 ms) and one rehearsal.
String _seedV4Database() {
  final dbPath = _seedV3Database();
  final raw = raw_sqlite3.sqlite3.open(dbPath);
  raw.execute('''
    CREATE TABLE rehearsal_logs (
      id TEXT NOT NULL PRIMARY KEY,
      song_id TEXT NOT NULL REFERENCES songs (id) ON DELETE CASCADE,
      started_at INTEGER NOT NULL,
      ended_at INTEGER NOT NULL,
      duration_ms INTEGER NOT NULL,
      mode TEXT NOT NULL,
      local_role TEXT NULL,
      max_participants INTEGER NOT NULL,
      loop_count INTEGER NOT NULL
    );
  ''');
  raw.execute(
    'CREATE INDEX rehearsal_logs_song_id ON rehearsal_logs (song_id);',
  );
  raw.execute(
    'INSERT INTO song_tracks (id, song_id, file_path, naipe, start_delay_ms, '
    "is_playback, is_playback_slot) VALUES ('t-sop', 'ave-1', "
    "'/library/tracks/abc.mp3', 'soprano', 400, 0, 0)",
  );
  raw.execute(
    'INSERT INTO rehearsal_logs (id, song_id, started_at, ended_at, '
    'duration_ms, mode, max_participants, loop_count) VALUES '
    "('log-1', 'ave-1', 1764100800, 1764101700, 900000, 'solo', 1, 3)",
  );
  raw.execute('PRAGMA user_version = 4;');
  raw.close();
  return dbPath;
}

/// A schema-v5 database file: the v4 library plus a custom naipe on its
/// track. Deleted after the test.
String _seedV5Database() {
  final dbPath = _seedV4Database();
  final raw = raw_sqlite3.sqlite3.open(dbPath);
  raw.execute('''
    CREATE TABLE custom_naipes (
      id TEXT NOT NULL PRIMARY KEY,
      name TEXT NOT NULL,
      name_key TEXT NOT NULL UNIQUE
    );
  ''');
  raw.execute('ALTER TABLE song_tracks ADD COLUMN custom_naipe_id TEXT NULL '
      'REFERENCES custom_naipes (id)');
  raw.execute('ALTER TABLE song_tracks ADD COLUMN file_name TEXT NULL');
  raw.execute(
      'ALTER TABLE song_tracks ADD COLUMN file_size_bytes INTEGER NULL');
  raw.execute('INSERT INTO custom_naipes (id, name, name_key) '
      "VALUES ('n-solista', 'Solista', 'solista')");
  raw.execute("UPDATE song_tracks SET custom_naipe_id = 'n-solista'");
  raw.execute('PRAGMA user_version = 5;');
  raw.close();
  return dbPath;
}

const _localProfileColumns = {'id', 'device_id', 'display_name', 'created_at'};
