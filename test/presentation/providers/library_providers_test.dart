import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/core/unit.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/entities/song_origin.dart';
import 'package:cantae/domain/repositories/song_repository.dart';
import 'package:cantae/presentation/providers/library_providers.dart';
import 'package:cantae/presentation/providers/song_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSongRepository implements SongRepository {
  _FakeSongRepository(this._songs);

  final List<Song> _songs;

  @override
  Future<Result<List<Song>, StorageFailure>> getAll() async =>
      Result.success(_songs);

  @override
  Future<Result<Unit, StorageFailure>> save(Song song) =>
      throw UnimplementedError();

  @override
  Future<Result<Song, Failure>> getById(String id) =>
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

Song _song({
  required String id,
  required String name,
  required String author,
  SongOrigin origin = SongOrigin.created,
  DateTime? lastRehearsedAt,
}) {
  return Song(
    id: id,
    name: name,
    author: author,
    origin: origin,
    lastRehearsedAt: lastRehearsedAt,
  );
}

ProviderContainer _containerFor(List<Song> songs) {
  final container = ProviderContainer(
    overrides: [
      songRepositoryProvider.overrideWithValue(_FakeSongRepository(songs)),
    ],
  );
  return container;
}

void main() {
  group('visibleSongsProvider', () {
    test('LibrarySortOrder.name sorts alphabetically, case-insensitive',
        () async {
      final songs = [
        _song(id: '1', name: 'zebra', author: 'A'),
        _song(id: '2', name: 'Ave Maria', author: 'B'),
        _song(id: '3', name: 'banho', author: 'C'),
      ];
      final container = _containerFor(songs);
      addTearDown(container.dispose);

      await container.read(songsProvider.future);
      final visible = container.read(visibleSongsProvider).value!;

      expect(visible.map((s) => s.id), ['2', '3', '1']);
    });

    test(
      'LibrarySortOrder.lastRehearsed sorts descending with null-lastRehearsed songs last',
      () async {
        final now = DateTime(2026);
        final songs = [
          _song(id: '1', name: 'A', author: 'x'),
          _song(
            id: '2',
            name: 'B',
            author: 'x',
            lastRehearsedAt: now.subtract(const Duration(days: 1)),
          ),
          _song(id: '3', name: 'C', author: 'x', lastRehearsedAt: now),
        ];
        final container = _containerFor(songs);
        addTearDown(container.dispose);

        await container.read(songsProvider.future);
        container.read(sortOrderProvider.notifier).state =
            LibrarySortOrder.lastRehearsed;
        final visible = container.read(visibleSongsProvider).value!;

        expect(visible.map((s) => s.id), ['3', '2', '1']);
      },
    );

    test('originFilterProvider alone narrows to the matching origin', () async {
      final songs = [
        _song(id: '1', name: 'A', author: 'x'),
        _song(id: '2', name: 'B', author: 'x', origin: SongOrigin.received),
      ];
      final container = _containerFor(songs);
      addTearDown(container.dispose);

      await container.read(songsProvider.future);
      container.read(originFilterProvider.notifier).state = SongOrigin.received;
      final visible = container.read(visibleSongsProvider).value!;

      expect(visible.map((s) => s.id), ['2']);
    });

    test(
        'searchQueryProvider alone matches case-insensitive name or author substring',
        () async {
      final songs = [
        _song(id: '1', name: 'Ave Maria', author: 'Marina Silva'),
        _song(id: '2', name: 'Panis Angelicus', author: 'José Pereira'),
      ];
      final container = _containerFor(songs);
      addTearDown(container.dispose);

      await container.read(songsProvider.future);
      container.read(searchQueryProvider.notifier).state = 'MARINA';
      final visible = container.read(visibleSongsProvider).value!;

      expect(visible.map((s) => s.id), ['1']);
    });

    test('combined origin filter and search narrow together', () async {
      final songs = [
        _song(id: '1', name: 'Ave Maria', author: 'Marina Silva'),
        _song(
          id: '2',
          name: 'Ave Maria (recebida)',
          author: 'Marina Silva',
          origin: SongOrigin.received,
        ),
      ];
      final container = _containerFor(songs);
      addTearDown(container.dispose);

      await container.read(songsProvider.future);
      container.read(searchQueryProvider.notifier).state = 'ave maria';
      container.read(originFilterProvider.notifier).state = SongOrigin.received;
      final visible = container.read(visibleSongsProvider).value!;

      expect(visible.map((s) => s.id), ['2']);
    });
  });

  group('highlightedSongIdProvider', () {
    test(
      'returns the id of the song with the latest non-null lastRehearsedAt, '
      'independent of search/filter/sort',
      () async {
        final now = DateTime(2026);
        final songs = [
          _song(id: '1', name: 'A', author: 'x', lastRehearsedAt: now),
          _song(
            id: '2',
            name: 'B',
            author: 'x',
            lastRehearsedAt: now.add(const Duration(days: 1)),
          ),
        ];
        final container = _containerFor(songs);
        addTearDown(container.dispose);

        await container.read(songsProvider.future);
        container.read(searchQueryProvider.notifier).state = 'nonexistent';
        final highlighted = container.read(highlightedSongIdProvider);

        expect(highlighted, '2');
      },
    );

    test(
      'ties on the exact same lastRehearsedAt millisecond go to whichever '
      'song appears first in the repository order',
      () async {
        final at = DateTime(2026);
        final songs = [
          _song(id: 'first', name: 'A', author: 'x', lastRehearsedAt: at),
          _song(id: 'second', name: 'B', author: 'x', lastRehearsedAt: at),
        ];
        final container = _containerFor(songs);
        addTearDown(container.dispose);

        await container.read(songsProvider.future);
        final highlighted = container.read(highlightedSongIdProvider);

        expect(highlighted, 'first');
      },
    );

    test('returns null when no song has ever been rehearsed', () async {
      final songs = [
        _song(id: '1', name: 'A', author: 'x'),
        _song(id: '2', name: 'B', author: 'x'),
      ];
      final container = _containerFor(songs);
      addTearDown(container.dispose);

      await container.read(songsProvider.future);
      final highlighted = container.read(highlightedSongIdProvider);

      expect(highlighted, isNull);
    });
  });
}
