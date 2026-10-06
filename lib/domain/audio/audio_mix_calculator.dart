abstract final class AudioMixCalculator {
  static double ownGain(double mix) => mix.clamp(0.0, 1.0);

  static double choirGain(double mix) => 1.0 - mix.clamp(0.0, 1.0);
}
