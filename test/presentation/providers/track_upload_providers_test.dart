import 'dart:io';

import 'package:cantae/data/library/song_tracks_saver.dart';
import 'package:cantae/data/library/track_file_importer.dart';
import 'package:cantae/domain/entities/song_origin.dart';
import 'package:cantae/infrastructure/database/app_database.dart';
import 'package:cantae/infrastructure/files/file_picker_track_file_picker.dart';
import 'package:cantae/presentation/providers/song_repository_provider.dart';
import 'package:cantae/presentation/providers/track_upload_providers.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Failure modes (UPL-03, UPL-15): the saver writes to a different database
// than the song repository the screens read; the custom naipe list reads a
// different database; the app picker is not the file_picker adapter.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('the saver and the custom naipe list share the app database', () async {
    final dir = Directory.systemTemp.createTempSync('cantae_providers');
    addTearDown(() => dir.deleteSync(recursive: true));
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      trackFileImporterProvider.overrideWithValue(
        TrackFileImporter(resolveRoot: () async => dir),
      ),
    ]);
    addTearDown(container.dispose);

    final saved = await container.read(songTracksSaverProvider).save(
          const SongSaveRequest(
            songId: 'ave',
            name: 'Ave Verum Corpus',
            author: 'Mozart',
            base: null,
            tracks: [],
          ),
        );
    expect(saved.isSuccess, isTrue);

    final song = (await container.read(songRepositoryProvider).getById('ave'))
        .when(success: (s) => s, failure: (f) => fail(f.code));
    expect(song.origin, SongOrigin.created);
    expect(
      (await container.read(customNaipeRepositoryProvider).getAll()).isSuccess,
      isTrue,
    );
    expect(
      container.read(trackFilePickerProvider),
      isA<FilePickerTrackFilePicker>(),
    );
  });
}
