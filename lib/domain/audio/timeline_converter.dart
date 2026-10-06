abstract final class TimelineConverter {
  static int toTrackLocal({required int timelineMs, required int startDelayMs}) {
    assert(startDelayMs >= 0, 'startDelayMs must be >= 0');
    final local = timelineMs - startDelayMs;
    return local < 0 ? 0 : local;
  }

  static int toTimeline({required int trackLocalMs, required int startDelayMs}) {
    assert(startDelayMs >= 0, 'startDelayMs must be >= 0');
    return trackLocalMs + startDelayMs;
  }
}
