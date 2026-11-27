import 'package:cantae/data/ids/uuid_v4.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/entities/local_profile.dart';
import 'package:cantae/domain/repositories/local_profile_repository.dart';
import 'package:cantae/infrastructure/database/app_database.dart';
import 'package:drift/drift.dart';

/// The one-row `local_profile` table (AD-014).
class DriftLocalProfileRepository implements LocalProfileRepository {
  DriftLocalProfileRepository(
    this._db, {
    String Function() newId = uuidV4,
    DateTime Function() now = DateTime.now,
  })  : _newId = newId,
        _now = now;

  static const _rowId = 1;

  final AppDatabase _db;
  final String Function() _newId;
  final DateTime Function() _now;

  @override
  Future<Result<LocalProfile, StorageFailure>> load() async {
    try {
      return Result.success(_toProfile(await _row()));
    } catch (_) {
      return Result.failure(StorageFailure(code: 'local_profile_read_failed'));
    }
  }

  @override
  Future<Result<LocalProfile, StorageFailure>> saveDisplayName(
    String name,
  ) async {
    try {
      await _row();
      await (_db.update(_db.localProfileTable)
            ..where((r) => r.id.equals(_rowId)))
          .write(LocalProfileTableCompanion(displayName: Value(name)));
      return Result.success(_toProfile(await _row()));
    } catch (_) {
      return Result.failure(StorageFailure(code: 'local_profile_save_failed'));
    }
  }

  /// The profile row, created with a new device id when missing.
  Future<LocalProfileTableData> _row() async {
    final query = _db.select(_db.localProfileTable)
      ..where((r) => r.id.equals(_rowId));
    final existing = await query.getSingleOrNull();
    if (existing != null) return existing;
    await _db.into(_db.localProfileTable).insert(
          LocalProfileTableCompanion.insert(
            id: const Value(_rowId),
            deviceId: _newId(),
            createdAt: _now(),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return query.getSingle();
  }

  LocalProfile _toProfile(LocalProfileTableData row) =>
      LocalProfile(deviceId: row.deviceId, displayName: row.displayName);
}
