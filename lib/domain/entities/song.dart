import 'package:cantae/domain/entities/lyric_line.dart';
import 'package:cantae/domain/entities/song_track.dart';

class Song {
  final String id;
  final String name;
  final String author;
  final List<SongTrack> tracks;
  final List<LyricLine> lyrics;

  const Song({
    required this.id,
    required this.name,
    required this.author,
    this.tracks = const [],
    this.lyrics = const [],
  });
}
