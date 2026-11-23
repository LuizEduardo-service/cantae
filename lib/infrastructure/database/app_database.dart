import 'package:drift/drift.dart';
import 'package:cantae/infrastructure/database/tables/songs_table.dart';
import 'package:cantae/infrastructure/database/tables/song_tracks_table.dart';
import 'package:cantae/infrastructure/database/tables/lyric_lines_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [SongsTable, SongTracksTable, LyricLinesTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 3;

  // SPEC_DEVIATION: AD-009/design.md's original sketch named drift's
  // `stepByStep(from1To2: ...)` helper. That helper now only exists as
  // `VersionedSchema.stepByStepHelper`, generated from an exported schema
  // snapshot (`drift_dev schema generate`) that this project has never
  // adopted (see design.md's Risks & Concerns). `Migrator.addColumn` is the
  // same additive primitive the helper would have called internally, used
  // directly in a hand-written `onUpgrade` step — still additive-only, still
  // versioned by `from`, just without the codegen layer.
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(songsTable, songsTable.origin);
            await m.addColumn(songsTable, songsTable.lastRehearsedAt);
          }
          if (from < 3) {
            // SQLite has no ALTER COLUMN, and addColumn cannot drop NOT NULL
            // from onset_ms. alterTable rebuilds lyric_lines from the current
            // (nullable) schema and copies every existing row unchanged.
            await m.alterTable(TableMigration(lyricLinesTable));
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON;');
        },
      );
}
