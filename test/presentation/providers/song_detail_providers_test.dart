import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/core/unit.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/repositories/song_repository.dart';
import 'package:cantae/presentation/providers/song_detail_providers.dart';
import 'package:cantae/presentation/providers/song_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSongRepository implements SongRepository {
  _FakeSongRepository(this._getById);

  final Future<Result<Song, Failure>> Function(String id) _getById;

  @override
  Future<Result<Song, Failure>> getById(String id) => _getById(id);

  @override
  Future<Result<List<Song>, StorageFailure>> getAll() =>
      throw UnimplementedError();

  @override
  Future<Result<Unit, StorageFailure>> save(Song song) =>
      throw UnimplementedError();

  @override
  Future<Result<Unit, Failure>> delete(String id) => throw UnimplementedError();

  @override
  Future<Result<Unit, StorageFailure>> deleteAll() =>
      throw UnimplementedError();

  @override
  Future<Result<Unit, Failure>> markRehearsed(String id, DateTime at) =>
      throw UnimplementedError();
}

ProviderContainer _containerFor(
  Future<Result<Song, Failure>> Function(String id) getById,
) {
  return ProviderContainer(
    overrides: [
      songRepositoryProvider.overrideWithValue(_FakeSongRepository(getById)),
    ],
  );
}

void main() {
  group('songByIdProvider', () {
    test('resolves AsyncData(Result.success(song)) when the song exists',
        () async {
      const song = Song(id: 's1', name: 'Song', author: 'Author');
      final container = _containerFor(
        (id) async => const Result.success(song),
      );
      addTearDown(container.dispose);

      final result = await container.read(songByIdProvider('s1').future);

      expect(result.isSuccess, isTrue);
      final value = result.when(success: (s) => s, failure: (_) => null);
      expect(value, same(song));
    });

    test(
      'resolves AsyncData(Result.failure(NotFoundFailure)) without AsyncError, when the song does not exist',
      () async {
        final container = _containerFor(
          (id) async => Result.failure(NotFoundFailure(code: 'song_not_found')),
        );
        addTearDown(container.dispose);

        await container.read(songByIdProvider('missing').future);
        final asyncValue = container.read(songByIdProvider('missing'));

        expect(asyncValue.hasError, isFalse);
        expect(asyncValue.value!.isFailure, isTrue);
        final failure = asyncValue.value!.when(
          success: (_) => null,
          failure: (f) => f,
        );
        expect(failure, isA<NotFoundFailure>());
        expect(failure!.code, equals('song_not_found'));
      },
    );

    test(
      'resolves AsyncData(Result.failure(other)) without AsyncError, for a non-not-found failure',
      () async {
        final container = _containerFor(
          (id) async => Result.failure(StorageFailure(code: 'song_db_error')),
        );
        addTearDown(container.dispose);

        final result = await container.read(songByIdProvider('s2').future);

        expect(result.isFailure, isTrue);
        final failure = result.when(success: (_) => null, failure: (f) => f);
        expect(failure, isA<StorageFailure>());
        expect(failure!.code, equals('song_db_error'));
      },
    );
  });
}
