import 'package:cantae/domain/repositories/song_repository.dart';
import 'package:cantae/infrastructure/database/app_database.dart';
import 'package:cantae/presentation/providers/song_repository_provider.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test(
    'songRepositoryProvider resolves to a working SongRepository backed by '
    'an overridden (in-memory) AppDatabase',
    () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWith(
            (ref) => AppDatabase(NativeDatabase.memory()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final repo = container.read(songRepositoryProvider);
      expect(repo, isA<SongRepository>());

      // Proves it's a real, working connection, not just a non-null object.
      final result = await repo.getAll();
      expect(result.isSuccess, isTrue);
    },
  );
}
