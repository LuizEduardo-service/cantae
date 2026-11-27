import 'package:drift/drift.dart';

/// This device's identity and the name it shows in rooms (AD-014). Always
/// a single row with [id] 1.
class LocalProfileTable extends Table {
  @override
  String get tableName => 'local_profile';

  IntColumn get id => integer()();
  TextColumn get deviceId => text()();
  TextColumn get displayName => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
