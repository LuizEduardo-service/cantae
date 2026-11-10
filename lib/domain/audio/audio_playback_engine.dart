import '../entities/song.dart';

abstract class AudioPlaybackEngine {
  Future<void> loadSong(Song song);

  Future<void> playAt(DateTime scheduledStart);

  Future<void> pause();

  Future<void> stop();

  Future<void> seekAllTo(int timelineMs);
}
