import 'package:cantae/data/mappers/lyric_line_mapper.dart';
import 'package:cantae/data/mappers/song_mapper.dart';
import 'package:cantae/data/mappers/song_track_mapper.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/core/unit.dart';
import 'package:cantae/domain/entities/custom_naipe.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/entities/song_track.dart';
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

        // New custom naipes join the device list (UPL-15); existing ones
        // are left as they are.
        final customNaipes = {
          for (final track in song.tracks)
            if (track.customNaipe != null) track.customNaipe!,
        };
        for (final naipe in customNaipes) {
          await _db.into(_db.customNaipesTable).insert(
                SongTrackMapper.customNaipeCompanion(naipe),
                mode: InsertMode.insertOrIgnore,
              );
        }

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
          // Saved (manual) order: save() reinserts lyrics in list order, so
          // rowId mirrors it. onsetMs may be null for unmarked lines.
          ..orderBy([(l) => OrderingTerm.asc(l.rowId)]))
        .get();

    final customNaipes = await _customNaipesFor(trackRows);
    SongTrack toTrack(SongTracksTableData row) =>
        SongTrackMapper.fromRow(row, customNaipes: customNaipes);

    final tracks =
        trackRows.where((row) => !row.isPlaybackSlot).map(toTrack).toList();
    final playbackRow =
        trackRows.where((row) => row.isPlaybackSlot).firstOrNull;

    final song = SongMapper.fromRow(
      songRow,
      tracks: tracks,
      lyrics: lyricRows.map(LyricLineMapper.fromRow).toList(),
      playbackTrack: playbackRow == null ? null : toTrack(playbackRow),
    );

    return Result.success(song);
  }

  @override
  Future<Result<List<Song>, StorageFailure>> getAll() async {
    final songRows = await _db.select(_db.songsTable).get();
    if (songRows.isEmpty) {
      return const Result.success(<Song>[]);
    }

    final songIds = songRows.map((row) => row.id).toList();
    final trackRows = await (_db.select(_db.songTracksTable)
          ..where((t) => t.songId.isIn(songIds)))
        .get();
    final lyricRows = await (_db.select(_db.lyricLinesTable)
          ..where((l) => l.songId.isIn(songIds))
          // Saved (manual) order: save() reinserts lyrics in list order, so
          // rowId mirrors it. onsetMs may be null for unmarked lines.
          ..orderBy([(l) => OrderingTerm.asc(l.rowId)]))
        .get();

    final customNaipes = await _customNaipesFor(trackRows);
    SongTrack toTrack(SongTracksTableData row) =>
        SongTrackMapper.fromRow(row, customNaipes: customNaipes);

    final tracksBySong = <String, List<SongTracksTableData>>{};
    for (final row in trackRows) {
      tracksBySong.putIfAbsent(row.songId, () => []).add(row);
    }
    final lyricsBySong = <String, List<LyricLinesTableData>>{};
    for (final row in lyricRows) {
      lyricsBySong.putIfAbsent(row.songId, () => []).add(row);
    }

    final songs = songRows.map((songRow) {
      final allTracks = tracksBySong[songRow.id] ?? const [];
      final tracks =
          allTracks.where((row) => !row.isPlaybackSlot).map(toTrack).toList();
      final playbackRow =
          allTracks.where((row) => row.isPlaybackSlot).firstOrNull;

      return SongMapper.fromRow(
        songRow,
        tracks: tracks,
        lyrics: (lyricsBySong[songRow.id] ?? const [])
            .map(LyricLineMapper.fromRow)
            .toList(),
        playbackTrack: playbackRow == null ? null : toTrack(playbackRow),
      );
    }).toList();

    return Result.success(songs);
  }

  /// Every custom naipe [rows] reference, in one query (no N+1).
  Future<Map<String, CustomNaipe>> _customNaipesFor(
    List<SongTracksTableData> rows,
  ) async {
    final ids = {
      for (final row in rows)
        if (row.customNaipeId != null) row.customNaipeId!,
    };
    if (ids.isEmpty) return const {};
    final naipeRows = await (_db.select(_db.customNaipesTable)
          ..where((n) => n.id.isIn(ids)))
        .get();
    return {
      for (final row in naipeRows)
        row.id: CustomNaipe(id: row.id, name: row.name),
    };
  }

  @override
  Future<Result<Unit, Failure>> delete(String id) async {
    final existing = await (_db.select(_db.songsTable)
          ..where((s) => s.id.equals(id)))
        .getSingleOrNull();

    if (existing == null) {
      return Result.failure(NotFoundFailure(code: 'song_not_found'));
    }

    await (_db.delete(_db.songsTable)..where((s) => s.id.equals(id))).go();

    return const Result.success(Unit());
  }

  @override
  Future<Result<Unit, StorageFailure>> deleteAll() async {
    await _db.delete(_db.songsTable).go();
    return const Result.success(Unit());
  }

  @override
  Future<Result<Unit, Failure>> markRehearsed(String id, DateTime at) async {
    final existing = await (_db.select(_db.songsTable)
          ..where((s) => s.id.equals(id)))
        .getSingleOrNull();

    if (existing == null) {
      return Result.failure(NotFoundFailure(code: 'song_not_found'));
    }

    await (_db.update(_db.songsTable)..where((s) => s.id.equals(id))).write(
      SongsTableCompanion(lastRehearsedAt: Value(at)),
    );

    return const Result.success(Unit());
  }
}
