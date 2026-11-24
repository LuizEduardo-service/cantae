import 'package:cantae/domain/audio/lyric_cursor.dart';
import 'package:cantae/domain/entities/lyric_line.dart';
import 'package:flutter_test/flutter_test.dart';

// Failure modes (CLAUDE.md, testing rule 3), written before the code:
// 1. Empty list: nothing to show; any index would be out of range.
// 2. Position before the first onset: no current line yet, but the first
//    line must already show as "Próxima" (spec P4-AC2).
// 3. Position exactly on an onset: that line is current (onset <= position),
//    not the previous one (off-by-one on the comparison).
// 4. Position between two lines: the earlier one stays current until the
//    next onset arrives.
// 5. Position after the last line: the last line stays current, and there
//    is no next line (index past the end).
// 6. Two lines with the same onset: the later one in lyric order is current,
//    so the cursor never points at a line that was already replaced.
// 7. First line current: there is no previous line (index -1).

const _lines = [
  LyricLine(text: 'Ave verum corpus', onsetMs: 2000),
  LyricLine(text: 'natum de Maria Virgine', onsetMs: 5000),
  LyricLine(text: 'vere passum immolatum', onsetMs: 9000),
];

void main() {
  group('LyricCursor.at', () {
    test('an empty list has no previous, current or next line', () {
      expect(
        LyricCursor.at(const [], 1000),
        (previous: null, current: null, next: null),
      );
    });

    test('before the first onset there is no current line; next is the first',
        () {
      expect(
        LyricCursor.at(_lines, 1999),
        (previous: null, current: null, next: 0),
      );
    });

    test('exactly on an onset, that line is current', () {
      expect(
        LyricCursor.at(_lines, 5000),
        (previous: 0, current: 1, next: 2),
      );
    });

    test('between two onsets, the earlier line stays current', () {
      expect(
        LyricCursor.at(_lines, 8999),
        (previous: 0, current: 1, next: 2),
      );
    });

    test('after the last onset, the last line is current with no next', () {
      expect(
        LyricCursor.at(_lines, 60000),
        (previous: 1, current: 2, next: null),
      );
    });

    test('the first line current has no previous line', () {
      expect(
        LyricCursor.at(_lines, 2000),
        (previous: null, current: 0, next: 1),
      );
    });

    test('two lines with the same onset: the later one in lyric order wins',
        () {
      const tied = [
        LyricLine(text: 'Ave', onsetMs: 1000),
        LyricLine(text: 'verum', onsetMs: 3000),
        LyricLine(text: 'corpus', onsetMs: 3000),
        LyricLine(text: 'natum', onsetMs: 7000),
      ];

      expect(
        LyricCursor.at(tied, 3000),
        (previous: 1, current: 2, next: 3),
      );
    });
  });
}
