import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final songTracksSaverProvider = Provider<SongTracksSaver>(
  (ref) => SongTracksSaver(
    repository: ref.watch(songRepositoryProvider),
    importer: ref.watch(trackFileImporterProvider),
  ),
);

final customNaipeRepositoryProvider = Provider<CustomNaipeRepository>(
  (ref) => DriftCustomNaipeRepository(ref.watch(appDatabaseProvider)),
);
