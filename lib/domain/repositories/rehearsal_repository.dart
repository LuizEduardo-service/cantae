import '../core/failures.dart';
import '../core/result.dart';
import '../core/unit.dart';
import '../entities/rehearsal_log.dart';

/// Rehearsal history kept on this device only (RF39, RF40).
abstract class RehearsalRepository {
  Future<Result<Unit, StorageFailure>> add(RehearsalLog log);

  /// That song's rehearsals, newest first.
  Future<Result<List<RehearsalLog>, StorageFailure>> getBySong(String songId);

  Future<Result<Unit, StorageFailure>> deleteBySong(String songId);

  Future<Result<Unit, StorageFailure>> deleteAll();
}
