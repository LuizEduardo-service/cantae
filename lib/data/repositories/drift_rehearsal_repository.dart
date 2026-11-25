import 'package:cantae/data/mappers/rehearsal_log_mapper.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/core/unit.dart';
import 'package:cantae/domain/entities/rehearsal_log.dart';
import 'package:cantae/domain/repositories/rehearsal_repository.dart';
import 'package:cantae/infrastructure/database/app_database.dart';
import 'package:drift/drift.dart';

class DriftRehearsalRepository implements RehearsalRepository {
  DriftRehearsalRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Result<Unit, StorageFailure>> add(RehearsalLog log) async {
    try {
      await _db
          .into(_db.rehearsalLogsTable)
          .insert(RehearsalLogMapper.toCompanion(log));
      return const Result.success(Unit());
    } catch (_) {
      return Result.failure(StorageFailure(code: 'rehearsal_save_failed'));
    }
  }

  @override
  Future<Result<List<RehearsalLog>, StorageFailure>> getBySong(
    String songId,
  ) async {
    try {
      final rows = await (_db.select(_db.rehearsalLogsTable)
            ..where((r) => r.songId.equals(songId))
            ..orderBy([(r) => OrderingTerm.desc(r.startedAt)]))
          .get();
      return Result.success(rows.map(RehearsalLogMapper.fromRow).toList());
    } catch (_) {
      return Result.failure(StorageFailure(code: 'rehearsal_read_failed'));
    }
  }

  @override
  Future<Result<Unit, StorageFailure>> deleteBySong(String songId) =>
      _delete(_db.delete(_db.rehearsalLogsTable)
        ..where((r) => r.songId.equals(songId)));

  @override
  Future<Result<Unit, StorageFailure>> deleteAll() =>
      _delete(_db.delete(_db.rehearsalLogsTable));

  Future<Result<Unit, StorageFailure>> _delete(
    DeleteStatement<$RehearsalLogsTableTable, RehearsalLogsTableData> query,
  ) async {
    try {
      await query.go();
      return const Result.success(Unit());
    } catch (_) {
      return Result.failure(StorageFailure(code: 'rehearsal_delete_failed'));
    }
  }
}
