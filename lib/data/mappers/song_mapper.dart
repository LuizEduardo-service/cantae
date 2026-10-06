import 'package:drift/drift.dart';
import 'package:cantae/domain/entities/lyric_line.dart';
import 'package:cantae/domain/entities/metronome_config.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/entities/song_track.dart';
import 'package:cantae/infrastructure/database/app_database.dart';

class SongMapper {
  SongMapper._();

  static SongsTableCompanion toCompanion(Song song) {
    final config = song.metronomeConfig;
    return SongsTableCompanion.insert(
      id: song.id,
      name: song.name,
      author: song.author,
      version: song.version,
      metronomeBpm: Value(config?.bpm),
      metronomeBeatsPerMeasure: Value(config?.beatsPerMeasure),
      metronomeDownbeatAccent: Value(config?.downbeatAccent),
      metronomeEnabledByDefault: Value(config?.enabledByDefault),
    );
  }

  /// Builds the song's scalar fields; [tracks], [lyrics], and [playbackTrack]
  /// are assembled by the repository from the other two mappers.
  static Song fromRow(
    SongsTableData row, {
    required List<SongTrack> tracks,
    required List<LyricLine> lyrics,
    required SongTrack? playbackTrack,
  }) {
    final hasConfig = row.metronomeBpm != null &&
        row.metronomeBeatsPerMeasure != null &&
        row.metronomeDownbeatAccent != null &&
        row.metronomeEnabledByDefault != null;

    return Song(
      id: row.id,
      name: row.name,
      author: row.author,
      version: row.version,
      tracks: tracks,
      lyrics: lyrics,
      playbackTrack: playbackTrack,
      metronomeConfig: hasConfig
          ? MetronomeConfig(
              bpm: row.metronomeBpm!,
              beatsPerMeasure: row.metronomeBeatsPerMeasure!,
              downbeatAccent: row.metronomeDownbeatAccent!,
              enabledByDefault: row.metronomeEnabledByDefault!,
            )
          : null,
    );
  }
}
