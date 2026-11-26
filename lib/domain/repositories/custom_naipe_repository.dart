import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/entities/custom_naipe.dart';

/// The device's reusable custom naipes (RF17). New ones are stored when a
/// song that uses them is saved (`SongRepository.save`).
abstract class CustomNaipeRepository {
  /// Every custom naipe on this device, sorted by name.
  Future<Result<List<CustomNaipe>, StorageFailure>> getAll();
}
