import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/domain/entities/lyric_line.dart';

void main() {
  group('LyricLine.onsetMs', () {
    test('null (not yet marked) constructs and stays null', () {
      // ignore: prefer_const_constructors
      final line = LyricLine(text: 'Ave Maria', onsetMs: null);
      expect(line.onsetMs, isNull);
    });

    test('0 (marked at the very start) constructs and is distinct from null',
        () {
      // ignore: prefer_const_constructors
      final line = LyricLine(text: 'Ave Maria', onsetMs: 0);
      expect(line.onsetMs, 0);
    });

    test('negative value is rejected by the constructor assert', () {
      expect(
        // ignore: prefer_const_constructors
        () => LyricLine(text: 'Ave Maria', onsetMs: -1),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('LyricLine.text', () {
    test('empty text is still rejected by the constructor assert', () {
      expect(
        // ignore: prefer_const_constructors
        () => LyricLine(text: '', onsetMs: null),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
