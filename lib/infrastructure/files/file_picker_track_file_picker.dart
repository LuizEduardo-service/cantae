import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/library/track_file_picker.dart';
import 'package:file_picker/file_picker.dart';

/// [TrackFilePicker] backed by `file_picker` (AD-013): the system chooser,
/// filtered to audio, one file.
class FilePickerTrackFilePicker implements TrackFilePicker {
  const FilePickerTrackFilePicker();

  @override
  Future<Result<PickedTrackFile?, StorageFailure>> pick() async {
    try {
      final file = await FilePicker.pickFile(type: FileType.audio);
      if (file == null) return const Result.success(null);
      // Android and iOS hand back a local copy; a file without a local path
      // cannot be read by the inspector.
      final path = file.path;
      if (path == null) {
        return Result.failure(StorageFailure(code: 'picker_failed'));
      }
      return Result.success(PickedTrackFile(path: path, name: file.name));
    } catch (_) {
      return Result.failure(StorageFailure(code: 'picker_failed'));
    }
  }

  @override
  Future<void> releaseTemporaryFiles() async {
    try {
      await FilePicker.clearTemporaryFiles();
    } catch (_) {
      // Leftover cache copies are harmless; the OS may clear them too.
    }
  }
}
