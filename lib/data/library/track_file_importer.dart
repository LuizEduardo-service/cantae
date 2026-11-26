import 'dart:io';
import 'dart:isolate';

import 'package:cantae/data/library/track_file_inspector.dart';
import 'package:cantae/data/transfer/library_storage_paths.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:crypto/crypto.dart';

/// A track file now in the library. [created] is false when an identical
/// file was already there and was reused, so a rollback must keep it.
class ImportedTrackFile {
  final String path;
  final bool created;

  const ImportedTrackFile({required this.path, required this.created});
}

/// SHA-256 of the file at [path], streamed inside `Isolate.run`.
Future<String> sha256OfFile(String path) => Isolate.run(
      () async => (await sha256.bind(File(path).openRead()).first).toString(),
    );

/// Copies picked files into the content-addressed library and keeps a copy
/// only when its hash matches the original (UPL-04, UPL-10, UPL-22).
class TrackFileImporter {
  TrackFileImporter({
    required Future<Directory> Function() resolveRoot,
    Future<String> Function(String path) hashFile = sha256OfFile,
  })  : _resolveRoot = resolveRoot,
        _hashFile = hashFile;

  final Future<Directory> Function() _resolveRoot;
  final Future<String> Function(String path) _hashFile;

  Future<Result<ImportedTrackFile, StorageFailure>> import(
    InspectedTrackFile file,
  ) async {
    File? part;
    try {
      final target = File(
        LibraryStoragePaths.trackFilePath(
          root: await _resolveRoot(),
          sha256: file.sha256,
          extension: file.format.extension,
        ),
      );
      if (await target.exists()) {
        if (await _hashFile(target.path) == file.sha256) {
          return Result.success(
            ImportedTrackFile(path: target.path, created: false),
          );
        }
      }
      // Copy beside the final path first: a half-written file never sits
      // at the content-addressed name.
      part = await File(file.sourcePath).copy('${target.path}.part');
      if (await _hashFile(part.path) != file.sha256) {
        await _deleteQuietly(part);
        return Result.failure(StorageFailure(code: 'track_hash_mismatch'));
      }
      if (await target.exists()) await target.delete();
      await part.rename(target.path);
      return Result.success(
          ImportedTrackFile(path: target.path, created: true));
    } on FileSystemException {
      if (part != null) await _deleteQuietly(part);
      return Result.failure(StorageFailure(code: 'track_copy_failed'));
    }
  }

  /// Removes [file] if this import created it; a reused file stays.
  Future<void> discard(ImportedTrackFile file) async {
    if (file.created) await _deleteQuietly(File(file.path));
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Nothing more to do: the file stays an orphan for Privacidade.
    }
  }
}
