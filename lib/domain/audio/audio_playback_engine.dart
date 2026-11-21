import '../entities/song.dart';

abstract class AudioPlaybackEngine {
  Future<void> loadSong(Song song);

  Future<void> playAt(DateTime scheduledStart);

  Future<void> pause();

  Future<void> stop();

  Future<void> seekAllTo(int timelineMs);

  /// Mutes/unmutes a single track. Other tracks' volume is unaffected.
  Future<void> setTrackMuted(String trackId, bool muted);

  /// Solos a single track, silencing every other loaded track. Soloing is
  /// exclusive: activating it on one track clears any other track's solo.
  /// Passing `solo: false` clears solo only if `trackId` currently holds it.
  Future<void> setTrackSolo(String trackId, bool solo);

  /// Changes the start delay used by [seekAllTo] for this track, without
  /// reloading its audio file.
  Future<void> setTrackStartDelayMs(String trackId, int startDelayMs);

  /// Total timeline duration — `null` until [loadSong] resolves, then the
  /// maximum of `startDelayMs + file duration` across loaded tracks.
  int? get durationMs;

  /// Current timeline position, derived from a reference track.
  Stream<int> get positionMs;
}
