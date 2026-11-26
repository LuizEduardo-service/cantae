import 'package:cantae/data/ids/uuid_v4.dart';
import 'package:cantae/data/library/track_file_importer.dart';
import 'package:cantae/data/library/track_file_inspector.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/entities/custom_naipe.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/entities/song_origin.dart';
import 'package:cantae/domain/entities/song_track.dart';
import 'package:cantae/domain/repositories/song_repository.dart';

/// One track of the song being saved: either a saved track kept as it is,
/// or a newly picked file for a slot.
class TrackChoice {
  final SongTrack? kept;
  final InspectedTrackFile? newFile;
  final Naipe naipe;
  final bool isPlayback;
  final CustomNaipe? customNaipe;

  TrackChoice.kept(SongTrack track)
      : kept = track,
        newFile = null,
        naipe = track.naipe,
        isPlayback = track.isPlayback,
        customNaipe = track.customNaipe;

  const TrackChoice.newFile({
    required this.naipe,
    required InspectedTrackFile file,
    this.isPlayback = false,
    this.customNaipe,
  })  : kept = null,
        newFile = file;
}

class SongSaveRequest {
  final String songId;
  final String name;
  final String author;

  /// The saved song being edited; null for a new song.
  final Song? base;
  final List<TrackChoice> tracks;

  const SongSaveRequest({
    required this.songId,
    required this.name,
    required this.author,
    required this.base,
    required this.tracks,
  });
}

/// Imports the new files and saves the song in one go (UPL-04, UPL-10,
/// UPL-19). If any step fails, every file this save created is removed.
class SongTracksSaver {
  SongTracksSaver({
    required SongRepository repository,
    required TrackFileImporter importer,
    String Function() newId = uuidV4,
  })  : _repository = repository,
        _importer = importer,
        _newId = newId;

  final SongRepository _repository;
  final TrackFileImporter _importer;
  final String Function() _newId;

  Future<Result<Song, Failure>> save(SongSaveRequest request) async {
    final imported = <ImportedTrackFile>[];
    final tracks = <SongTrack>[];
    SongTrack? playback;

    Future<void> rollback() async {
      for (final file in imported) {
        await _importer.discard(file);
      }
    }

    for (final choice in request.tracks) {
      final track = choice.kept ?? await _importNew(choice, imported);
      if (track == null) {
        await rollback();
        return Result.failure(StorageFailure(code: 'track_import_failed'));
      }
      if (track.isPlayback) {
        playback = track;
      } else {
        tracks.add(track);
      }
    }

    final base = request.base;
    final song = Song(
      id: request.songId,
      name: request.name,
      author: request.author,
      version: base?.version ?? '',
      tracks: tracks,
      lyrics: base?.lyrics ?? const [],
      metronomeConfig: base?.metronomeConfig,
      playbackTrack: playback,
      origin: base?.origin ?? SongOrigin.created,
      lastRehearsedAt: base?.lastRehearsedAt,
    );

    final saveFailure = (await _repository.save(song))
        .when<Failure?>(success: (_) => null, failure: (f) => f);
    if (saveFailure != null) {
      await rollback();
      return Result.failure(saveFailure);
    }
    return Result.success(song);
  }

  /// Imports [choice]'s file and returns its new track (delay 0), or null.
  Future<SongTrack?> _importNew(
    TrackChoice choice,
    List<ImportedTrackFile> imported,
  ) async {
    final file = choice.newFile!;
    final result = await _importer.import(file);
    return result.when(
      success: (copy) {
        imported.add(copy);
        return SongTrack(
          id: _newId(),
          filePath: copy.path,
          naipe: choice.naipe,
          isPlayback: choice.isPlayback,
          customNaipe: choice.customNaipe,
          fileName: file.name,
          fileSizeBytes: file.sizeBytes,
        );
      },
      failure: (_) => null,
    );
  }
}
