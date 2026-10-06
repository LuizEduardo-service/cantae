import 'package:drift/drift.dart';
import 'package:cantae/infrastructure/database/tables/songs_table.dart';

class SongTracksTable extends Table {
  @override
  String get tableName => 'song_tracks';

  TextColumn get id => text()();
  TextColumn get songId =>
      text().references(SongsTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get filePath => text()();
  TextColumn get naipe => text()();
  IntColumn get startDelayMs => integer()();
  BoolColumn get isPlayback => boolean()();
  BoolColumn get isPlaybackSlot =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
