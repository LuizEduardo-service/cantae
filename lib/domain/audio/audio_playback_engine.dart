import '../entities/song.dart';
import '../entities/song_track.dart';

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

  /// Sets a track's volume, clamped to `0.0..1.0`. It multiplies the track's
  /// base gain and still obeys [setTrackMuted] and [setTrackSolo]: a muted
  /// track, or any track other than the soloed one, stays silent.
  Future<void> setTrackVolume(String trackId, double volume);

  /// Loads one more track into the current session (e.g. the metronome's
  /// click track) without reloading the others. It starts at volume 1.0,
  /// unmuted, and follows [seekAllTo], [playAt], [pause] and the per-track
  /// mix. With [exemptFromSolo], soloing another track does not silence it.
  /// It never becomes the position reference.
  Future<void> addTrack(SongTrack track, {bool exemptFromSolo = false});

  /// Stops and releases a track added or loaded before. Unknown ids are a
  /// no-op.
  Future<void> removeTrack(String trackId);

  /// Changes the start delay used by [seekAllTo] for this track, without
  /// reloading its audio file.
  Future<void> setTrackStartDelayMs(String trackId, int startDelayMs);

  /// Total timeline duration — `null` until [loadSong] resolves, then the
  /// maximum of `startDelayMs + file duration` across loaded tracks.
  int? get durationMs;

  /// Current timeline position, derived from a reference track.
  Stream<int> get positionMs;
}
