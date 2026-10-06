import 'package:drift/drift.dart';
import 'package:cantae/infrastructure/database/tables/songs_table.dart';
import 'package:cantae/infrastructure/database/tables/song_tracks_table.dart';
import 'package:cantae/infrastructure/database/tables/lyric_lines_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [SongsTable, SongTracksTable, LyricLinesTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON;');
        },
      );
}
