import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/entities/local_profile.dart';

abstract class LocalProfileRepository {
  /// The device profile. The first call creates it with a new device id;
  /// later calls return the same id.
  Future<Result<LocalProfile, StorageFailure>> load();

  /// Stores [name] (already validated) as the name shown in rooms.
  Future<Result<LocalProfile, StorageFailure>> saveDisplayName(String name);
}
