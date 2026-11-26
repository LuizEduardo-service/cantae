import 'package:drift/drift.dart';
import 'package:cantae/infrastructure/database/tables/custom_naipes_table.dart';
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

  /// Set only on `naipe = custom` tracks with a named naipe (track-upload).
  TextColumn get customNaipeId =>
      text().nullable().references(CustomNaipesTable, #id)();
  TextColumn get fileName => text().nullable()();
  IntColumn get fileSizeBytes => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
