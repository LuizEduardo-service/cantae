import 'package:cantae/domain/entities/lyric_line.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/entities/song_track.dart';

class FixtureSongs {
  FixtureSongs._();

  static Song completeSong() => const Song(
        id: 'fixture-complete-001',
        name: 'Complete Song',
        author: 'Fixture Author',
        tracks: [
          SongTrack(id: 'track-s', filePath: 'soprano.mp3', naipe: Naipe.soprano),
          SongTrack(id: 'track-c', filePath: 'contralto.mp3', naipe: Naipe.contralto),
          SongTrack(id: 'track-t', filePath: 'tenor.mp3', naipe: Naipe.tenor),
          SongTrack(id: 'track-b', filePath: 'bass.mp3', naipe: Naipe.bass),
        ],
      );

  static Song incompleteSong() => const Song(
        id: 'fixture-incomplete-002',
        name: 'Incomplete Song',
        author: 'Fixture Author',
        tracks: [
          SongTrack(id: 'track-s', filePath: 'soprano.mp3', naipe: Naipe.soprano),
          SongTrack(id: 'track-c', filePath: 'contralto.mp3', naipe: Naipe.contralto),
          SongTrack(id: 'track-b', filePath: 'bass.mp3', naipe: Naipe.bass),
        ],
      );

  static Song offsetSong() => const Song(
        id: 'fixture-offset-003',
        name: 'Offset Song',
        author: 'Fixture Author',
        tracks: [
          SongTrack(id: 'track-s', filePath: 'soprano.mp3', naipe: Naipe.soprano),
          SongTrack(
            id: 'track-c',
            filePath: 'contralto.mp3',
            naipe: Naipe.contralto,
            startDelayMs: 350,
          ),
          SongTrack(
            id: 'track-t',
            filePath: 'tenor.mp3',
            naipe: Naipe.tenor,
            startDelayMs: 700,
          ),
          SongTrack(id: 'track-b', filePath: 'bass.mp3', naipe: Naipe.bass),
        ],
      );

  static Song songWithLyrics() => const Song(
        id: 'fixture-lyrics-004',
        name: 'Song With Lyrics',
        author: 'Fixture Author',
        tracks: [
          SongTrack(id: 'track-s', filePath: 'soprano.mp3', naipe: Naipe.soprano),
        ],
        lyrics: [
          LyricLine(text: 'First line of the song', onsetMs: 1000, naipe: Naipe.soprano),
          LyricLine(text: 'Second line continues', onsetMs: 3500, naipe: Naipe.soprano),
          LyricLine(text: 'Third line resolves', onsetMs: 6200, naipe: Naipe.soprano),
        ],
      );

  static Song invalidTrackSong() => const Song(
        id: 'fixture-invalid-005',
        name: 'Invalid Track Song',
        author: 'Fixture Author',
        tracks: [
          SongTrack(id: 'track-s', filePath: 'soprano.mp3', naipe: Naipe.soprano),
          // 'invalid' means the path points to a nonexistent file — the domain
          // invariant only guards against empty paths; file existence is
          // checked at the infrastructure layer.
          SongTrack(
            id: 'track-invalid',
            filePath: 'audio/nonexistent_file.mp3',
            naipe: Naipe.contralto,
          ),
        ],
      );
}
