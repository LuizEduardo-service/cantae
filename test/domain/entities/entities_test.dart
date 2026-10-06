import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/domain/entities/lyric_line.dart';
import 'package:cantae/domain/entities/metronome_config.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/entities/song_track.dart';

void main() {
  group('Song invariants', () {
    test('valid Song constructs without error', () {
      expect(
        () => const Song(id: 's1', name: 'Test Song', author: 'Author'),
        returnsNormally,
      );
    });

    test('empty id throws AssertionError', () {
      // ignore: prefer_const_constructors
      expect(() => Song(id: '', name: 'Test', author: 'A'), throwsA(isA<AssertionError>()));
    });

    test('empty name throws AssertionError', () {
      // ignore: prefer_const_constructors
      expect(() => Song(id: 's1', name: '', author: 'A'), throwsA(isA<AssertionError>()));
    });
  });

  group('SongTrack invariants', () {
    test('valid SongTrack constructs without error', () {
      expect(
        () => const SongTrack(id: 't1', filePath: 'soprano.mp3', naipe: Naipe.soprano),
        returnsNormally,
      );
    });

    test('empty id throws AssertionError', () {
      expect(
        // ignore: prefer_const_constructors
        () => SongTrack(id: '', filePath: 'soprano.mp3', naipe: Naipe.soprano),
        throwsA(isA<AssertionError>()),
      );
    });

    test('empty filePath throws AssertionError', () {
      expect(
        // ignore: prefer_const_constructors
        () => SongTrack(id: 't1', filePath: '', naipe: Naipe.soprano),
        throwsA(isA<AssertionError>()),
      );
    });

    test('negative startDelayMs throws AssertionError', () {
      expect(
        // ignore: prefer_const_constructors
        () => SongTrack(id: 't1', filePath: 'f.mp3', naipe: Naipe.soprano, startDelayMs: -1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('zero startDelayMs is valid', () {
      expect(
        () => const SongTrack(id: 't1', filePath: 'f.mp3', naipe: Naipe.soprano),
        returnsNormally,
      );
    });
  });

  group('LyricLine invariants', () {
    test('valid LyricLine constructs without error', () {
      expect(
        () => const LyricLine(text: 'First line', onsetMs: 1000),
        returnsNormally,
      );
    });

    test('empty text throws AssertionError', () {
      // ignore: prefer_const_constructors
      expect(() => LyricLine(text: '', onsetMs: 1000), throwsA(isA<AssertionError>()));
    });

    test('negative onsetMs throws AssertionError', () {
      // ignore: prefer_const_constructors
      expect(() => LyricLine(text: 'Line', onsetMs: -1), throwsA(isA<AssertionError>()));
    });

    test('zero onsetMs is valid', () {
      expect(() => const LyricLine(text: 'Line', onsetMs: 0), returnsNormally);
    });
  });

  group('MetronomeConfig invariants', () {
    test('valid MetronomeConfig constructs without error', () {
      expect(
        () => const MetronomeConfig(bpm: 120, beatsPerMeasure: 4),
        returnsNormally,
      );
    });

    test('bpm below 30 throws AssertionError', () {
      expect(
        // ignore: prefer_const_constructors
        () => MetronomeConfig(bpm: 29, beatsPerMeasure: 4),
        throwsA(isA<AssertionError>()),
      );
    });

    test('bpm above 300 throws AssertionError', () {
      expect(
        // ignore: prefer_const_constructors
        () => MetronomeConfig(bpm: 301, beatsPerMeasure: 4),
        throwsA(isA<AssertionError>()),
      );
    });

    test('bpm boundary 30 is valid', () {
      expect(() => const MetronomeConfig(bpm: 30, beatsPerMeasure: 4), returnsNormally);
    });

    test('bpm boundary 300 is valid', () {
      expect(() => const MetronomeConfig(bpm: 300, beatsPerMeasure: 4), returnsNormally);
    });

    test('beatsPerMeasure below 2 throws AssertionError', () {
      expect(
        // ignore: prefer_const_constructors
        () => MetronomeConfig(bpm: 120, beatsPerMeasure: 1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('beatsPerMeasure above 16 throws AssertionError', () {
      expect(
        // ignore: prefer_const_constructors
        () => MetronomeConfig(bpm: 120, beatsPerMeasure: 17),
        throwsA(isA<AssertionError>()),
      );
    });

    test('beatsPerMeasure boundary 2 is valid', () {
      expect(() => const MetronomeConfig(bpm: 120, beatsPerMeasure: 2), returnsNormally);
    });

    test('beatsPerMeasure boundary 16 is valid', () {
      expect(() => const MetronomeConfig(bpm: 120, beatsPerMeasure: 16), returnsNormally);
    });
  });
}
