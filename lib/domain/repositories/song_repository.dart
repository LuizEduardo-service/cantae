import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/core/unit.dart';
import 'package:cantae/domain/entities/song.dart';

abstract class SongRepository {
  Future<Result<Unit, StorageFailure>> save(Song song);

  Future<Result<Song, Failure>> getById(String id);

  Future<Result<List<Song>, StorageFailure>> getAll();

  Future<Result<Unit, Failure>> delete(String id);

  Future<Result<Unit, StorageFailure>> deleteAll();
}
