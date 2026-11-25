import 'package:cantae/data/repositories/drift_rehearsal_repository.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/entities/rehearsal_log.dart';
import 'package:cantae/infrastructure/database/app_database.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// Failure modes (HIST-03, HIST-11, HIST-14, HIST-15):
// - a field is lost or altered on the way to the database and back
//   (especially a null role, dates and counts);
// - getBySong mixes songs or returns oldest first;
// - deleteBySong removes other songs' rehearsals;
// - deleteAll leaves rows behind;
// - a database error escapes as an exception instead of a StorageFailure.
RehearsalLog _log(
  String id, {
  String songId = 'ave',
  int startHour = 19,
  RehearsalRole? role,
}) =>
    RehearsalLog(
      id: id,
      songId: songId,
      startedAt: DateTime(2026, 11, 25, startHour, 40),
      endedAt: DateTime(2026, 11, 25, startHour, 52, 30),
      durationMs: 750000,
      mode: role == null ? RehearsalMode.solo : RehearsalMode.room,
      localRole: role,
      maxParticipants: role == null ? 1 : 6,
      loopCount: 8,
    );

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late DriftRehearsalRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftRehearsalRepository(db);
    for (final id in ['ave', 'aleluia']) {
      await db.into(db.songsTable).insert(SongsTableCompanion.insert(
            id: id,
            name: id,
            author: 'Mozart',
            version: '',
          ));
    }
  });

  tearDown(() => db.close());

  List<RehearsalLog> logsOf(Result<List<RehearsalLog>, StorageFailure> r) =>
      r.when(success: (logs) => logs, failure: (f) => fail('$f'));

  test('every field round-trips, with and without a role', () async {
    await repo.add(_log('solo-1'));
    await repo.add(_log('room-1', startHour: 20, role: RehearsalRole.singer));

    final logs = logsOf(await repo.getBySong('ave'));
    final room = logs.firstWhere((l) => l.id == 'room-1');
    final solo = logs.firstWhere((l) => l.id == 'solo-1');
    expect(solo.songId, 'ave');
    expect(solo.startedAt, DateTime(2026, 11, 25, 19, 40));
    expect(solo.endedAt, DateTime(2026, 11, 25, 19, 52, 30));
    expect(solo.durationMs, 750000);
    expect(solo.mode, RehearsalMode.solo);
    expect(solo.localRole, isNull);
    expect(solo.maxParticipants, 1);
    expect(solo.loopCount, 8);
    expect(room.mode, RehearsalMode.room);
    expect(room.localRole, RehearsalRole.singer);
    expect(room.maxParticipants, 6);
  });

  test('getBySong returns only that song, newest first', () async {
    await repo.add(_log('old', startHour: 9));
    await repo.add(_log('other', songId: 'aleluia', startHour: 21));
    await repo.add(_log('new', startHour: 20));

    final logs = logsOf(await repo.getBySong('ave'));
    expect(logs.map((l) => l.id), ['new', 'old']);
  });

  test('a song without rehearsals returns an empty list', () async {
    expect(logsOf(await repo.getBySong('ave')), isEmpty);
  });

  test('deleteBySong keeps other songs', () async {
    await repo.add(_log('a1'));
    await repo.add(_log('b1', songId: 'aleluia'));

    expect((await repo.deleteBySong('ave')).isSuccess, isTrue);

    expect(logsOf(await repo.getBySong('ave')), isEmpty);
    expect(logsOf(await repo.getBySong('aleluia')).map((l) => l.id), ['b1']);
  });

  test('deleteAll removes every rehearsal', () async {
    await repo.add(_log('a1'));
    await repo.add(_log('b1', songId: 'aleluia'));

    expect((await repo.deleteAll()).isSuccess, isTrue);

    expect(logsOf(await repo.getBySong('ave')), isEmpty);
    expect(logsOf(await repo.getBySong('aleluia')), isEmpty);
  });

  test('database errors are StorageFailures, never exceptions', () async {
    await db.close();

    Future<void> expectFailure(
      Future<Result<Object?, StorageFailure>> call,
      String code,
    ) async {
      final result = await call;
      expect(result.isFailure, isTrue, reason: code);
      result.when(
        success: (_) => fail('expected $code'),
        failure: (f) => expect(f.code, code),
      );
    }

    await expectFailure(repo.add(_log('x')), 'rehearsal_save_failed');
    await expectFailure(repo.getBySong('ave'), 'rehearsal_read_failed');
    await expectFailure(repo.deleteBySong('ave'), 'rehearsal_delete_failed');
    await expectFailure(repo.deleteAll(), 'rehearsal_delete_failed');
  });
}
