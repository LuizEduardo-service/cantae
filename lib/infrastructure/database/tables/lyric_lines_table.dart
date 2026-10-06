import 'package:drift/drift.dart';
import 'package:cantae/infrastructure/database/tables/songs_table.dart';

class LyricLinesTable extends Table {
  @override
  String get tableName => 'lyric_lines';

  IntColumn get rowId => integer().autoIncrement()();
  TextColumn get songId =>
      text().references(SongsTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get lyricText => text().named('text')();
  IntColumn get onsetMs => integer()();
  TextColumn get naipe => text().nullable()();
  TextColumn get dynamics => text().nullable()();
}
