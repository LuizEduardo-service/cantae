import 'package:drift/drift.dart';
import 'package:cantae/infrastructure/database/tables/songs_table.dart';

/// One recorded rehearsal (PRD `RehearsalLog`). Deleting the song deletes
/// its rehearsals (rehearsal-history HIST-18).
@TableIndex(name: 'rehearsal_logs_song_id', columns: {#songId})
class RehearsalLogsTable extends Table {
  @override
  String get tableName => 'rehearsal_logs';

  TextColumn get id => text()();
  TextColumn get songId =>
      text().references(SongsTable, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime()();
  IntColumn get durationMs => integer()();
  TextColumn get mode => text()();
  TextColumn get localRole => text().nullable()();
  IntColumn get maxParticipants => integer()();
  IntColumn get loopCount => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
