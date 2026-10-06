import 'package:cantae/data/mappers/lyric_line_mapper.dart';
import 'package:cantae/data/mappers/song_mapper.dart';
import 'package:cantae/data/mappers/song_track_mapper.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/core/unit.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/repositories/song_repository.dart';
import 'package:cantae/infrastructure/database/app_database.dart';
import 'package:drift/drift.dart';

class DriftSongRepository implements SongRepository {
  DriftSongRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Result<Unit, StorageFailure>> save(Song song) async {
    try {
      await _db.transaction(() async {
        await _db.into(_db.songsTable).insertOnConflictUpdate(
              SongMapper.toCompanion(song),
            );

        await (_db.delete(_db.songTracksTable)
              ..where((t) => t.songId.equals(song.id)))
            .go();
        await (_db.delete(_db.lyricLinesTable)
              ..where((l) => l.songId.equals(song.id)))
            .go();

        for (final track in song.tracks) {
          await _db.into(_db.songTracksTable).insert(
                SongTrackMapper.toCompanion(
                  track,
                  songId: song.id,
                  isPlaybackSlot: false,
                ),
              );
        }
        final playbackTrack = song.playbackTrack;
        if (playbackTrack != null) {
          await _db.into(_db.songTracksTable).insert(
                SongTrackMapper.toCompanion(
                  playbackTrack,
                  songId: song.id,
                  isPlaybackSlot: true,
                ),
              );
        }

        for (final line in song.lyrics) {
          await _db.into(_db.lyricLinesTable).insert(
                LyricLineMapper.toCompanion(line, songId: song.id),
              );
        }
      });

      return const Result.success(Unit());
    } catch (_) {
      return Result.failure(StorageFailure(code: 'song_save_failed'));
    }
  }

  @override
  Future<Result<Song, Failure>> getById(String id) async {
    final songRow = await (_db.select(_db.songsTable)
          ..where((s) => s.id.equals(id)))
        .getSingleOrNull();

    if (songRow == null) {
      return Result.failure(NotFoundFailure(code: 'song_not_found'));
    }

    final trackRows = await (_db.select(_db.songTracksTable)
          ..where((t) => t.songId.equals(id)))
        .get();
    final lyricRows = await (_db.select(_db.lyricLinesTable)
          ..where((l) => l.songId.equals(id))
          ..orderBy([
            (l) => OrderingTerm.asc(l.onsetMs),
            (l) => OrderingTerm.asc(l.rowId),
          ]))
        .get();

    final tracks = trackRows
        .where((row) => !row.isPlaybackSlot)
        .map(SongTrackMapper.fromRow)
        .toList();
    final playbackRow = trackRows.where((row) => row.isPlaybackSlot).firstOrNull;

    final song = SongMapper.fromRow(
      songRow,
      tracks: tracks,
      lyrics: lyricRows.map(LyricLineMapper.fromRow).toList(),
      playbackTrack: playbackRow == null ? null : SongTrackMapper.fromRow(playbackRow),
    );

    return Result.success(song);
  }

  @override
  Future<Result<List<Song>, StorageFailure>> getAll() => throw UnimplementedError();

  @override
  Future<Result<Unit, Failure>> delete(String id) => throw UnimplementedError();

  @override
  Future<Result<Unit, StorageFailure>> deleteAll() => throw UnimplementedError();
}
