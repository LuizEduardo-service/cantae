import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/ids/uuid_v4.dart';
import '../../data/library/library_file_releaser.dart';
import '../../data/library/song_tracks_saver.dart';
import '../../data/library/track_file_importer.dart';
import '../../data/library/track_file_inspector.dart';
import '../../data/repositories/drift_custom_naipe_repository.dart';
import '../../data/transfer/library_storage_paths.dart';
import '../../domain/library/track_file_picker.dart';
import '../../domain/repositories/custom_naipe_repository.dart';
import '../../infrastructure/files/file_picker_track_file_picker.dart';
import 'song_repository_provider.dart';

/// The system file chooser (AD-013). Overridden in tests with a fake.
final trackFilePickerProvider = Provider<TrackFilePicker>(
  (ref) => const FilePickerTrackFilePicker(),
);

final trackFileInspectorProvider = Provider<TrackFileInspector>(
  (ref) => const TrackFileInspector(),
);

/// Copies tracks into `library/tracks/`. Overridden in tests with a
/// temporary root.
final trackFileImporterProvider = Provider<TrackFileImporter>(
  (ref) => TrackFileImporter(
    resolveRoot: LibraryStoragePaths.resolveLibraryRoot,
  ),
);

/// Deletes library files no track uses any more. Overridden in tests with a
/// temporary root.
final libraryFileReleaserProvider = Provider<LibraryFileReleaser>(
  (ref) => LibraryFileReleaser(
    repository: ref.watch(songRepositoryProvider),
    resolveRoot: LibraryStoragePaths.resolveLibraryRoot,
  ),
);

final songTracksSaverProvider = Provider<SongTracksSaver>(
  (ref) => SongTracksSaver(
    repository: ref.watch(songRepositoryProvider),
    importer: ref.watch(trackFileImporterProvider),
    releaser: ref.watch(libraryFileReleaserProvider),
  ),
);

final customNaipeRepositoryProvider = Provider<CustomNaipeRepository>(
  (ref) => DriftCustomNaipeRepository(ref.watch(appDatabaseProvider)),
);

/// Ids for new songs and custom naipes. Overridden in tests.
final newIdProvider = Provider<String Function()>((ref) => uuidV4);
