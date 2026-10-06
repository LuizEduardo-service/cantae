import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/domain/audio/audio_mix_calculator.dart';

void main() {
  group('AudioMixCalculator.ownGain', () {
    test('mix 1.0 returns own gain 1.0', () {
      expect(AudioMixCalculator.ownGain(1.0), equals(1.0));
    });

    test('mix 0.0 returns own gain 0.0', () {
      expect(AudioMixCalculator.ownGain(0.0), equals(0.0));
    });

    test('mix 0.5 returns own gain 0.5', () {
      expect(AudioMixCalculator.ownGain(0.5), equals(0.5));
    });

    test('mix below 0.0 is clamped to 0.0', () {
      expect(AudioMixCalculator.ownGain(-0.1), equals(0.0));
    });

    test('mix above 1.0 is clamped to 1.0', () {
      expect(AudioMixCalculator.ownGain(1.1), equals(1.0));
    });
  });

  group('AudioMixCalculator.choirGain', () {
    test('mix 1.0 returns choir gain 0.0', () {
      expect(AudioMixCalculator.choirGain(1.0), equals(0.0));
    });

    test('mix 0.0 returns choir gain 1.0', () {
      expect(AudioMixCalculator.choirGain(0.0), equals(1.0));
    });

    test('mix below 0.0 choir gain is clamped to 1.0', () {
      expect(AudioMixCalculator.choirGain(-0.1), equals(1.0));
    });
  });

  group('AudioMixCalculator sum invariant', () {
    test('ownGain + choirGain == 1.0 for values in [0.0, 1.0]', () {
      for (final m in [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0]) {
        final sum = AudioMixCalculator.ownGain(m) + AudioMixCalculator.choirGain(m);
        expect(sum, closeTo(1.0, 1e-10), reason: 'sum != 1.0 for mix=$m');
      }
    });
  });
}
