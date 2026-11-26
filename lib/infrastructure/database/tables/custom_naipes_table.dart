import 'package:drift/drift.dart';

/// The device's reusable custom naipes (RF17). [nameKey] is the trimmed,
/// lowercased name, so "Solista" and "SOLISTA" cannot both exist.
class CustomNaipesTable extends Table {
  @override
  String get tableName => 'custom_naipes';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get nameKey => text().unique()();

  @override
  Set<Column> get primaryKey => {id};
}
