import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/core/unit.dart';
import 'package:cantae/domain/entities/rehearsal_log.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/repositories/rehearsal_repository.dart';
import 'package:cantae/domain/repositories/song_repository.dart';
import 'package:cantae/presentation/providers/library_providers.dart';
import 'package:cantae/presentation/providers/rehearsal_providers.dart';
import 'package:cantae/presentation/providers/song_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Failure modes (HIST-05, HIST-07):
// - the log is saved but the song's last-rehearsed date is not updated, so
//   the Library's "Último ensaio" sort never changes;
// - the song is marked even though the log failed to save;
// - the Library and the detail count keep stale data after recording;
// - a storage failure escapes record() and crashes leaving Modo solo.
class _FakeRehearsals implements RehearsalRepository {
  final List<RehearsalLog> added = [];
  bool failAdd = false;
  int reads = 0;

  @override
  Future<Result<Unit, StorageFailure>> add(RehearsalLog log) async {
    if (failAdd) {
      return Result.failure(StorageFailure(code: 'rehearsal_save_failed'));
    }
    added.add(log);
    return const Result.success(Unit());
  }

  @override
  Future<Result<List<RehearsalLog>, StorageFailure>> getBySong(
    String songId,
  ) async {
    reads++;
    return Result.success(added.where((l) => l.songId == songId).toList());
  }

  @override
  Future<Result<Unit, StorageFailure>> deleteBySong(String songId) async =>
      const Result.success(Unit());

  @override
  Future<Result<Unit, StorageFailure>> deleteAll() async =>
      const Result.success(Unit());
}

class _FakeSongs implements SongRepository {
  final List<(String, DateTime)> marked = [];
  bool failMark = false;
  int listReads = 0;

  @override
  Future<Result<Unit, Failure>> markRehearsed(String id, DateTime at) async {
    if (failMark) throw StateError('database closed');
    marked.add((id, at));
    return const Result.success(Unit());
  }

  @override
  Future<Result<List<Song>, StorageFailure>> getAll() async {
    listReads++;
    return const Result.success(<Song>[]);
  }

  @override
  Future<Result<Song, Failure>> getById(String id) async =>
      Result.success(Song(id: id, name: 'Ave Verum Corpus', author: 'Mozart'));

  @override
  Future<Result<Unit, StorageFailure>> save(Song song) =>
      throw UnimplementedError();

  @override
  Future<Result<Unit, Failure>> delete(String id) => throw UnimplementedError();

  @override
  Future<Result<Unit, StorageFailure>> deleteAll() =>
      throw UnimplementedError();
}

final _log = RehearsalLog(
  id: 'log-1',
  songId: 'ave',
  startedAt: DateTime(2026, 11, 25, 19, 40),
  endedAt: DateTime(2026, 11, 25, 19, 52, 30),
  durationMs: 750000,
  mode: RehearsalMode.solo,
  maxParticipants: 1,
  loopCount: 8,
);

void main() {
  late _FakeRehearsals rehearsals;
  late _FakeSongs songs;
  late ProviderContainer container;

  setUp(() {
    rehearsals = _FakeRehearsals();
    songs = _FakeSongs();
    container = ProviderContainer(overrides: [
      rehearsalRepositoryProvider.overrideWithValue(rehearsals),
      songRepositoryProvider.overrideWithValue(songs),
    ]);
    addTearDown(container.dispose);
  });

  test('record saves the log and marks the song with its end time', () async {
    await container.read(rehearsalRecorderProvider).record(_log);

    expect(rehearsals.added.single.id, 'log-1');
    expect(songs.marked.single, ('ave', DateTime(2026, 11, 25, 19, 52, 30)));
  });

  test('after record, the Library and the song count read again', () async {
    container.listen(songsProvider, (_, __) {});
    container.listen(rehearsalLogsProvider('ave'), (_, __) {});
    await container.read(songsProvider.future);
    await container.read(rehearsalLogsProvider('ave').future);
    final listReads = songs.listReads;
    final logReads = rehearsals.reads;

    await container.read(rehearsalRecorderProvider).record(_log);
    await container.read(songsProvider.future);
    final logs = await container.read(rehearsalLogsProvider('ave').future);

    expect(songs.listReads, listReads + 1);
    expect(rehearsals.reads, logReads + 1);
    expect(logs.when(success: (l) => l.length, failure: (_) => -1), 1);
  });

  test('a failed save neither marks the song nor throws', () async {
    rehearsals.failAdd = true;

    await container.read(rehearsalRecorderProvider).record(_log);

    expect(songs.marked, isEmpty);
  });

  test('a failure while marking the song does not throw', () async {
    songs.failMark = true;

    await expectLater(
      container.read(rehearsalRecorderProvider).record(_log),
      completes,
    );
    expect(rehearsals.added, hasLength(1));
  });

  test('the clock defaults to the real time', () {
    final before = DateTime.now();
    final now = container.read(clockProvider)();

    expect(now.isBefore(before), isFalse);
  });
}
