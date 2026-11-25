import '../entities/rehearsal_log.dart';

/// Measures one Modo solo session (rehearsal-history HIST-01..04):
/// only time with the music playing counts, a loop counts each time it
/// jumps back while playing, and a session under [minDuration] is not a
/// rehearsal.
class RehearsalSessionTracker {
  static const Duration minDuration = Duration(seconds: 60);

  DateTime? _startedAt;
  DateTime? _spanStart;
  int _playedMs = 0;
  int _loops = 0;

  /// Repeated values are ignored, so callers can report every state change.
  void setPlaying(bool playing, DateTime now) {
    final spanStart = _spanStart;
    if (playing) {
      if (spanStart != null) return;
      _startedAt ??= now;
      _spanStart = now;
      return;
    }
    if (spanStart == null) return;
    _playedMs += now.difference(spanStart).inMilliseconds;
    _spanStart = null;
  }

  void loopJumped() {
    if (_spanStart != null) _loops++;
  }

  /// Closes an open span at [now]. Null when the music never played or
  /// played for less than [minDuration].
  RehearsalLog? finish({
    required String id,
    required String songId,
    required DateTime now,
  }) {
    setPlaying(false, now);
    final startedAt = _startedAt;
    if (startedAt == null || _playedMs < minDuration.inMilliseconds) {
      return null;
    }
    return RehearsalLog(
      id: id,
      songId: songId,
      startedAt: startedAt,
      endedAt: now,
      durationMs: _playedMs,
      mode: RehearsalMode.solo,
      maxParticipants: 1,
      loopCount: _loops,
    );
  }
}
