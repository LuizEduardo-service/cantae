import 'dart:io';
import 'dart:isolate';

import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/library/audio_file_check.dart';
import 'package:cantae/domain/library/track_file_picker.dart';
import 'package:cantae/domain/transfer/chunk_planner.dart';
import 'package:crypto/crypto.dart';

/// A picked file that passed the audio check, with its SHA-256.
class InspectedTrackFile {
  final String sourcePath;
  final String name;
  final int sizeBytes;
  final String sha256;
  final AudioFormat format;

  const InspectedTrackFile({
    required this.sourcePath,
    required this.name,
    required this.sizeBytes,
    required this.sha256,
    required this.format,
  });
}

/// Reads a picked file's size, header and SHA-256 inside `Isolate.run`, so
/// a 100 MB file never blocks the UI thread (UPL-09), and applies the
/// domain's [checkTrackFile] (UPL-07, UPL-08).
class TrackFileInspector {
  const TrackFileInspector();

  Future<Result<InspectedTrackFile, ValidationFailure>> inspect(
    PickedTrackFile file,
  ) async {
    final path = file.path;
    final outcome = await Isolate.run(() => _inspect(path));
    final code = outcome.code;
    if (code != null) return Result.failure(ValidationFailure(code: code));
    return Result.success(
      InspectedTrackFile(
        sourcePath: path,
        name: file.name,
        sizeBytes: outcome.size,
        sha256: outcome.sha256!,
        format: outcome.format!,
      ),
    );
  }
}

typedef _Outcome = ({
  String? code,
  int size,
  String? sha256,
  AudioFormat? format,
});

Future<_Outcome> _inspect(String path) async {
  try {
    final file = File(path);
    final size = await file.length();
    if (size <= 0 || size > ChunkPlanner.maxTransferableSizeBytes) {
      // Size alone decides: nothing is read.
      return _rejected(checkTrackFile(sizeBytes: size, header: const []), size);
    }
    final raf = await file.open();
    final List<int> header;
    try {
      header = await raf.read(audioHeaderLength);
    } finally {
      await raf.close();
    }
    final checked = checkTrackFile(sizeBytes: size, header: header);
    if (checked.isFailure) return _rejected(checked, size);
    final digest = await sha256.bind(file.openRead()).first;
    return (
      code: null,
      size: size,
      sha256: digest.toString(),
      format: checked.when(success: (f) => f, failure: (_) => null),
    );
  } on FileSystemException {
    return (code: 'track_file_unreadable', size: 0, sha256: null, format: null);
  }
}

_Outcome _rejected(Result<AudioFormat, ValidationFailure> r, int size) => (
      code: r.when(
          success: (_) => 'track_file_unsupported', failure: (f) => f.code),
      size: size,
      sha256: null,
      format: null,
    );
