import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/entities/custom_naipe.dart';
import 'package:cantae/domain/repositories/custom_naipe_repository.dart';
import 'package:cantae/infrastructure/database/app_database.dart';
import 'package:drift/drift.dart';

class DriftCustomNaipeRepository implements CustomNaipeRepository {
  DriftCustomNaipeRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Result<List<CustomNaipe>, StorageFailure>> getAll() async {
    try {
      final rows = await (_db.select(_db.customNaipesTable)
            ..orderBy([(n) => OrderingTerm.asc(n.nameKey)]))
          .get();
      return Result.success(
        rows.map((r) => CustomNaipe(id: r.id, name: r.name)).toList(),
      );
    } catch (_) {
      return Result.failure(StorageFailure(code: 'custom_naipe_read_failed'));
    }
  }
}
