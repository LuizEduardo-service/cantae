import 'package:drift/drift.dart';
import 'package:cantae/domain/entities/custom_naipe.dart';
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
      customNaipeId: Value(track.customNaipe?.id),
      fileName: Value(track.fileName),
      fileSizeBytes: Value(track.fileSizeBytes),
    );
  }

  static CustomNaipesTableCompanion customNaipeCompanion(CustomNaipe naipe) =>
      CustomNaipesTableCompanion.insert(
        id: naipe.id,
        name: naipe.name,
        nameKey: naipe.name.trim().toLowerCase(),
      );

  /// [customNaipes] holds every custom naipe the row may reference, by id.
  static SongTrack fromRow(
    SongTracksTableData row, {
    Map<String, CustomNaipe> customNaipes = const {},
  }) {
    final customId = row.customNaipeId;
    return SongTrack(
      id: row.id,
      filePath: row.filePath,
      naipe: Naipe.values.byName(row.naipe),
      startDelayMs: row.startDelayMs,
      isPlayback: row.isPlayback,
      customNaipe: customId == null ? null : customNaipes[customId],
      fileName: row.fileName,
      fileSizeBytes: row.fileSizeBytes,
    );
  }
}
