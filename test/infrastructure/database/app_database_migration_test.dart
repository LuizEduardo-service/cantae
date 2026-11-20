import 'dart:io';

import 'package:cantae/infrastructure/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as raw_sqlite3;

void main() {
  group('AppDatabase migration v1 -> v2 (LIB-12)', () {
    test('upgrading from schema v1 preserves an existing row and backfills origin/lastRehearsedAt', () async {
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

    test('a fresh v2 install creates the origin/lastRehearsedAt columns directly via onCreate', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final columns = await db
          .customSelect("PRAGMA table_info('songs')")
          .get();
      final columnNames = columns.map((r) => r.data['name'] as String).toSet();

      expect(columnNames, containsAll(<String>['origin', 'last_rehearsed_at']));
    });
  });
}
