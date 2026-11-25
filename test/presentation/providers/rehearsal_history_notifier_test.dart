import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/core/unit.dart';
import 'package:cantae/domain/entities/rehearsal_log.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/repositories/rehearsal_repository.dart';
import 'package:cantae/domain/repositories/song_repository.dart';
import 'package:cantae/presentation/providers/rehearsal_history_notifier.dart';
import 'package:cantae/presentation/providers/rehearsal_providers.dart';
import 'package:cantae/presentation/providers/song_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Failure modes (HIST-10, HIST-11, HIST-13 to HIST-17):
// - totals computed from the wrong logs or rounded;
// - a missing song shown as an empty history;
// - a read error shown as "no rehearsals";
// - retry does not read again;
// - deleting one song's rehearsals deletes others, or keeps showing them;
// - a failed delete empties the list anyway;
// - the song detail count keeps the old number after deleting.
RehearsalLog _log(String id, String songId, int hour, int ms, int loops) =>
    RehearsalLog(
      id: id,
      songId: songId,
      startedAt: DateTime(2026, 11, 25, hour),
      endedAt: DateTime(2026, 11, 25, hour, 30),
      durationMs: ms,
      mode: RehearsalMode.solo,
      maxParticipants: 1,
      loopCount: loops,
    );

class _Rehearsals implements RehearsalRepository {
  final List<RehearsalLog> logs = [
    _log('a-old', 'ave', 9, 185000, 0),
    _log('a-new', 'ave', 20, 750000, 8),
    _log('b-1', 'aleluia', 10, 300000, 2),
  ];
  bool failRead = false;
  bool failDelete = false;
  int reads = 0;

  @override
  Future<Result<Unit, StorageFailure>> add(RehearsalLog log) =>
      throw UnimplementedError();

  @override
  Future<Result<List<RehearsalLog>, StorageFailure>> getBySong(
    String songId,
  ) async {
    reads++;
    if (failRead) {
      return Result.failure(StorageFailure(code: 'rehearsal_read_failed'));
    }
    final mine = logs.where((l) => l.songId == songId).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return Result.success(mine);
  }

  @override
  Future<Result<Unit, StorageFailure>> deleteBySong(String songId) async {
    if (failDelete) {
      return Result.failure(StorageFailure(code: 'rehearsal_delete_failed'));
    }
    logs.removeWhere((l) => l.songId == songId);
    return const Result.success(Unit());
  }

  @override
  Future<Result<Unit, StorageFailure>> deleteAll() async {
    if (failDelete) {
      return Result.failure(StorageFailure(code: 'rehearsal_delete_failed'));
    }
    logs.clear();
    return const Result.success(Unit());
  }
}

class _Songs implements SongRepository {
  bool missing = false;

  @override
  Future<Result<Song, Failure>> getById(String id) async => missing
      ? Result.failure(NotFoundFailure(code: 'song_not_found'))
      : Result.success(
          Song(id: id, name: 'Ave Verum Corpus', author: 'Mozart'));

  @override
  Future<Result<Unit, StorageFailure>> save(Song song) =>
      throw UnimplementedError();

  @override
  Future<Result<List<Song>, StorageFailure>> getAll() =>
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

Future<void> _flush() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _Rehearsals rehearsals;
  late _Songs songs;
  late ProviderContainer c;

  setUp(() {
    rehearsals = _Rehearsals();
    songs = _Songs();
    c = ProviderContainer(overrides: [
      rehearsalRepositoryProvider.overrideWithValue(rehearsals),
      songRepositoryProvider.overrideWithValue(songs),
    ]);
    addTearDown(c.dispose);
  });

  Future<void> open() async {
    c.listen(rehearsalHistoryProvider('ave'), (_, __) {});
    await _flush();
  }

  RehearsalHistoryState state() => c.read(rehearsalHistoryProvider('ave'));
  RehearsalHistoryNotifier notifier() =>
      c.read(rehearsalHistoryProvider('ave').notifier);

  test('starts loading', () {
    expect(state().status, RehearsalHistoryStatus.loading);
  });

  test('ready: song name, its logs newest first, and totals', () async {
    await open();

    expect(state().status, RehearsalHistoryStatus.ready);
    expect(state().songName, 'Ave Verum Corpus');
    expect(state().logs.map((l) => l.id), ['a-new', 'a-old']);
    expect(state().count, 2);
    expect(state().totalDurationMs, 935000);
    expect(state().totalLoops, 8);
  });

  test('a missing song is notFound', () async {
    songs.missing = true;
    await open();

    expect(state().status, RehearsalHistoryStatus.notFound);
  });

  test('a read error is error; retry reads again', () async {
    rehearsals.failRead = true;
    await open();
    expect(state().status, RehearsalHistoryStatus.error);

    rehearsals.failRead = false;
    notifier().retry();
    await _flush();

    expect(state().status, RehearsalHistoryStatus.ready);
    expect(state().count, 2);
  });

  test('deleteForSong empties this song only and refreshes the count',
      () async {
    await open();
    c.listen(rehearsalLogsProvider('ave'), (_, __) {});
    await c.read(rehearsalLogsProvider('ave').future);
    final reads = rehearsals.reads;

    expect(await notifier().deleteForSong(), isTrue);
    await c.read(rehearsalLogsProvider('ave').future);

    expect(state().logs, isEmpty);
    expect(state().deleteError, isNull);
    expect(rehearsals.logs.map((l) => l.id), ['b-1']);
    expect(rehearsals.reads, greaterThan(reads));
  });

  test('deleteAll empties every song', () async {
    await open();

    expect(await notifier().deleteAll(), isTrue);

    expect(state().logs, isEmpty);
    expect(rehearsals.logs, isEmpty);
  });

  test('a failed delete keeps the logs and reports it', () async {
    await open();
    rehearsals.failDelete = true;

    expect(await notifier().deleteForSong(), isFalse);
    expect(state().logs, hasLength(2));
    expect(state().deleteError, deleteRehearsalsFailedMessage);

    expect(await notifier().deleteAll(), isFalse);
    expect(state().logs, hasLength(2));
    expect(state().deleting, isFalse);
  });
}
