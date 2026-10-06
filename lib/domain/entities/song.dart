import 'package:cantae/domain/entities/lyric_line.dart';
import 'package:cantae/domain/entities/metronome_config.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/domain/entities/song_track.dart';

class Song {
  final String id;
  final String name;
  final String author;
  final String version;
  final List<SongTrack> tracks;
  final List<LyricLine> lyrics;
  final MetronomeConfig? metronomeConfig;
  final SongTrack? playbackTrack;

  const Song({
    required this.id,
    required this.name,
    required this.author,
    this.version = '',
    this.tracks = const [],
    this.lyrics = const [],
    this.metronomeConfig,
    this.playbackTrack,
  })  : assert(id.length > 0, 'Song.id must not be empty'),
        assert(name.length > 0, 'Song.name must not be empty');

  bool get isComplete {
    const standard = {Naipe.soprano, Naipe.contralto, Naipe.tenor, Naipe.bass};
    final covered = tracks
        .where((t) => !t.isPlayback && standard.contains(t.naipe))
        .map((t) => t.naipe)
        .toSet();
    return covered.containsAll(standard);
  }
}
