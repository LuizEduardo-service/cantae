import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/entities/song.dart';
import '../../domain/repositories/song_repository.dart';

Future<void> _deleteFromDisk(File file) => file.delete();

/// Deletes library files that no track uses any more, after a track is
/// replaced or removed, or a song is deleted.
///
/// The library is content-addressed, so two songs can share a file: a path
/// is deleted only when no song still uses it as a track or Playback, and
/// only when it sits inside the library folder. Best effort: a file that
/// cannot be deleted stays, and the rest go on.
class LibraryFileReleaser {
  LibraryFileReleaser({
    required SongRepository repository,
    required Future<Directory> Function() resolveRoot,
    Future<void> Function(File file)? deleteFile,
  })  : _repository = repository,
        _resolveRoot = resolveRoot,
        _deleteFile = deleteFile ?? _deleteFromDisk;

  final SongRepository _repository;
  final Future<Directory> Function() _resolveRoot;
  final Future<void> Function(File file) _deleteFile;

  /// Deletes each of [paths] no song uses. Returns how many were deleted.
  Future<int> release(Iterable<String> paths) async {
    final candidates = paths.toSet();
    if (candidates.isEmpty) return 0;

    final inUse = (await _repository.getAll()).when<Set<String>?>(
      success: (songs) => {for (final song in songs) ..._pathsOf(song)},
      failure: (_) => null,
    );
    if (inUse == null) return 0;

    final String root;
    try {
      root = p.normalize((await _resolveRoot()).absolute.path);
    } on Exception {
      return 0;
    }
    var deleted = 0;
    for (final path in candidates) {
      final normalized = p.normalize(File(path).absolute.path);
      if (inUse.contains(path) || !p.isWithin(root, normalized)) continue;
      final file = File(normalized);
      try {
        if (!await file.exists()) continue;
        await _deleteFile(file);
        deleted++;
      } on FileSystemException {
        // Stays on disk; the next release or a full data deletion clears it.
      }
    }
    return deleted;
  }

  static Iterable<String> _pathsOf(Song song) => [
        for (final track in song.tracks) track.filePath,
        if (song.playbackTrack case final playback?) playback.filePath,
      ];
}
