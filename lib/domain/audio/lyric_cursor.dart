import 'package:cantae/domain/entities/lyric_line.dart';

/// Indexes into a list of timed lyric lines: the line already sung before
/// the current one, the line being sung, and the line that comes next.
typedef LyricCursorResult = ({int? previous, int? current, int? next});

/// Where the playback position falls in a song's synced lyrics.
abstract final class LyricCursor {
  /// [timedLines] holds only lines with a non-null `onsetMs`, in lyric order.
  ///
  /// The current line is the one with the greatest onset at or before
  /// [positionMs]; on a tie, the later line in lyric order wins. Before the
  /// first onset there is no current line and the first line is next.
  static LyricCursorResult at(List<LyricLine> timedLines, int positionMs) {
    int? current;
    var bestOnset = -1;
    for (var i = 0; i < timedLines.length; i++) {
      final onset = timedLines[i].onsetMs;
      if (onset == null || onset > positionMs) continue;
      if (onset >= bestOnset) {
        bestOnset = onset;
        current = i;
      }
    }

    if (current == null) {
      return (
        previous: null,
        current: null,
        next: timedLines.isEmpty ? null : 0,
      );
    }
    return (
      previous: current > 0 ? current - 1 : null,
      current: current,
      next: current + 1 < timedLines.length ? current + 1 : null,
    );
  }
}
