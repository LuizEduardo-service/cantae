import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/domain/audio/metronome_pulse_generator.dart';
import 'package:cantae/domain/entities/metronome_config.dart';

void main() {
  group('MetronomePulseGenerator.generate', () {
    test('generates correct pulse count for 2-second window at 60 bpm', () {
      const config = MetronomeConfig(bpm: 60, beatsPerMeasure: 4);
      final pulses = MetronomePulseGenerator.generate(
        startMs: 0,
        durationMs: 2000,
        config: config,
      );
      // 60 bpm = 1 beat/s → beats at 0 ms and 1000 ms → 2 pulses
      expect(pulses.length, equals(2));
      expect(pulses[0].positionMs, equals(0));
      expect(pulses[1].positionMs, equals(1000));
    });

    test('beat index 0 is downbeat, indices 1-3 are not', () {
      const config = MetronomeConfig(bpm: 60, beatsPerMeasure: 4);
      final pulses = MetronomePulseGenerator.generate(
        startMs: 0,
        durationMs: 4000,
        config: config,
      );
      expect(pulses[0].isDownbeat, isTrue);
      expect(pulses[1].isDownbeat, isFalse);
      expect(pulses[2].isDownbeat, isFalse);
      expect(pulses[3].isDownbeat, isFalse);
    });

    test('first pulse aligns to next beat boundary when startMs is mid-beat',
        () {
      const config = MetronomeConfig(bpm: 60, beatsPerMeasure: 4);
      final pulses = MetronomePulseGenerator.generate(
        startMs: 500,
        durationMs: 2000,
        config: config,
      );
      // beats at 0, 1000, 2000... first beat >= 500 is 1000
      expect(pulses.first.positionMs, equals(1000));
    });

    test('consecutive pulses are spaced by 60000/bpm ms', () {
      const config = MetronomeConfig(bpm: 120, beatsPerMeasure: 4);
      const expectedInterval = 60000 ~/ 120; // 500 ms
      final pulses = MetronomePulseGenerator.generate(
        startMs: 0,
        durationMs: 4000,
        config: config,
      );
      for (var i = 1; i < pulses.length; i++) {
        expect(
          pulses[i].positionMs - pulses[i - 1].positionMs,
          equals(expectedInterval),
          reason: 'interval mismatch between pulse ${i - 1} and $i',
        );
      }
    });

    // Regression (solo-metronome spec, bug 3): the interval was the integer
    // 60000 ~/ bpm (833 ms at 72 BPM instead of 833.33), so the click fell
    // ~70 ms behind the music after 3 minutes.
    test('pulse n sits at round(n * 60000 / bpm): no cumulative drift', () {
      final pulses = MetronomePulseGenerator.generate(
        startMs: 0,
        durationMs: 180001,
        config: const MetronomeConfig(bpm: 72, beatsPerMeasure: 4),
      );

      expect(pulses[216].positionMs, 180000);
      for (var n = 0; n < pulses.length; n++) {
        expect(
            (pulses[n].positionMs - n * 60000 / 72).abs(), lessThanOrEqualTo(1),
            reason: 'pulse $n');
      }
    });

    test('a mid-song start keeps the same drift-free grid', () {
      final pulses = MetronomePulseGenerator.generate(
        startMs: 179500,
        durationMs: 1000,
        config: const MetronomeConfig(bpm: 72, beatsPerMeasure: 4),
      );

      expect(pulses.first.positionMs, 180000);
      expect(pulses.first.isDownbeat, isTrue,
          reason: 'pulse 216 is the first beat of measure 55');
    });

    test('empty list when durationMs is 0', () {
      const config = MetronomeConfig(bpm: 60, beatsPerMeasure: 4);
      final pulses = MetronomePulseGenerator.generate(
        startMs: 0,
        durationMs: 0,
        config: config,
      );
      expect(pulses, isEmpty);
    });

    test('downbeat repeats every beatsPerMeasure pulses', () {
      const config = MetronomeConfig(bpm: 60, beatsPerMeasure: 3);
      final pulses = MetronomePulseGenerator.generate(
        startMs: 0,
        durationMs: 6000,
        config: config,
      );
      // 6 pulses at 0,1,2,3,4,5 seconds; downbeats at indices 0 and 3
      expect(pulses[0].isDownbeat, isTrue);
      expect(pulses[3].isDownbeat, isTrue);
      expect(pulses[1].isDownbeat, isFalse);
      expect(pulses[2].isDownbeat, isFalse);
    });

    test('MetronomeConfig bpm validation still enforced (below 30)', () {
      expect(
        // ignore: prefer_const_constructors
        () => MetronomeConfig(bpm: 29, beatsPerMeasure: 4),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
