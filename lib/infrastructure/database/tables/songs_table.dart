import 'package:drift/drift.dart';

class SongsTable extends Table {
  @override
  String get tableName => 'songs';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get author => text()();
  TextColumn get version => text()();
  IntColumn get metronomeBpm => integer().nullable()();
  IntColumn get metronomeBeatsPerMeasure => integer().nullable()();
  BoolColumn get metronomeDownbeatAccent => boolean().nullable()();
  BoolColumn get metronomeEnabledByDefault => boolean().nullable()();
  TextColumn get origin => text().withDefault(const Constant('created'))();
  DateTimeColumn get lastRehearsedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
