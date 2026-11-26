import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';

/// A file the person chose in the system picker.
class PickedTrackFile {
  final String path;

  /// Display name as picked ("tenor.mp3").
  final String name;

  const PickedTrackFile({required this.path, required this.name});
}

/// Opens the system file chooser, filtered to audio (UPL-03). Implemented
/// in `infrastructure/`, so the plugin never reaches the domain or tests.
abstract class TrackFilePicker {
  /// The chosen file, `null` when the person cancels, or `picker_failed`
  /// when the system chooser could not open.
  Future<Result<PickedTrackFile?, StorageFailure>> pick();
}
