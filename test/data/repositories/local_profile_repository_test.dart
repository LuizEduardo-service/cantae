import 'dart:io';

import 'package:cantae/data/repositories/drift_local_profile_repository.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/entities/local_profile.dart';
import 'package:cantae/infrastructure/database/app_database.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

// Failure modes (ROOM-03, ROOM-48):
// - each load makes a new device id, so the master sees a new device every
//   time;
// - the device id changes when the app is opened again;
// - the room name is not kept, so the sheet asks again next time;
// - a database error escapes as an exception instead of a StorageFailure.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  LocalProfile profile(Result<LocalProfile, StorageFailure> r) =>
      r.when(success: (v) => v, failure: (f) => fail(f.code));

  test('two loads return the same device id and no name yet', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    var ids = 0;
    final repo = DriftLocalProfileRepository(db, newId: () => 'id-${ids++}');

    final first = profile(await repo.load());
    final second = profile(await repo.load());

    expect(first.deviceId, 'id-0');
    expect(second.deviceId, 'id-0');
    expect(first.displayName, isNull);
  });

  test('the device id and the name survive reopening the database', () async {
    final dir = Directory.systemTemp.createTempSync('cantae_profile');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File(p.join(dir.path, 'cantae.db'));

    final db1 = AppDatabase(NativeDatabase(file));
    final repo1 = DriftLocalProfileRepository(db1, newId: () => 'first');
    final created = profile(await repo1.load());
    expect(
        profile(await repo1.saveDisplayName('Marina')).displayName, 'Marina');
    await db1.close();

    final db2 = AppDatabase(NativeDatabase(file));
    addTearDown(db2.close);
    final reopened = profile(
        await DriftLocalProfileRepository(db2, newId: () => 'x').load());

    expect(reopened.deviceId, created.deviceId);
    expect(reopened.displayName, 'Marina');
  });

  test('saving a name before any load still keeps one device id', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = DriftLocalProfileRepository(db, newId: () => 'only');

    final saved = profile(await repo.saveDisplayName('Bruno'));
    final loaded = profile(await repo.load());

    expect(saved.deviceId, 'only');
    expect(loaded.deviceId, 'only');
    expect(loaded.displayName, 'Bruno');
  });

  test('a closed database fails with a StorageFailure', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = DriftLocalProfileRepository(db);
    profile(await repo.load());
    await db.close();

    final code = (await repo.saveDisplayName('Ana'))
        .when(success: (_) => null, failure: (f) => f.code);

    expect(code, isNotNull);
    expect(code, isNotEmpty);
  });
}
