class MetronomeConfig {
  final int bpm;
  final int beatsPerMeasure;
  final bool downbeatAccent;
  final bool enabledByDefault;

  const MetronomeConfig({
    required this.bpm,
    required this.beatsPerMeasure,
    this.downbeatAccent = true,
    this.enabledByDefault = false,
  })  : assert(bpm >= 30 && bpm <= 300, 'MetronomeConfig.bpm must be in [30, 300]'),
        assert(
          beatsPerMeasure >= 2 && beatsPerMeasure <= 16,
          'MetronomeConfig.beatsPerMeasure must be in [2, 16]',
        );
}
