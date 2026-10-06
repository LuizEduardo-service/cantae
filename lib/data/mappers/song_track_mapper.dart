import 'package:drift/drift.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/domain/entities/song_track.dart';
import 'package:cantae/infrastructure/database/app_database.dart';

class SongTrackMapper {
  SongTrackMapper._();

  static SongTracksTableCompanion toCompanion(
    SongTrack track, {
    required String songId,
    required bool isPlaybackSlot,
  }) {
    return SongTracksTableCompanion.insert(
      id: track.id,
      songId: songId,
      filePath: track.filePath,
      naipe: track.naipe.name,
      startDelayMs: track.startDelayMs,
      isPlayback: track.isPlayback,
      isPlaybackSlot: Value(isPlaybackSlot),
    );
  }

  static SongTrack fromRow(SongTracksTableData row) {
    return SongTrack(
      id: row.id,
      filePath: row.filePath,
      naipe: Naipe.values.byName(row.naipe),
      startDelayMs: row.startDelayMs,
      isPlayback: row.isPlayback,
    );
  }
}
