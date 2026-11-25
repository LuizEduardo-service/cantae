import 'package:cantae/domain/entities/metronome_config.dart';

final class MetronomePulse {
  final int positionMs;
  final bool isDownbeat;

  const MetronomePulse({required this.positionMs, required this.isDownbeat});
}

abstract final class MetronomePulseGenerator {
  static List<MetronomePulse> generate({
    required int startMs,
    required int durationMs,
    required MetronomeConfig config,
  }) {
    if (durationMs <= 0) return const [];

    // Each pulse sits at its own rounded absolute position. Adding an
    // integer interval (60000 ~/ bpm) accumulated the rounding error: at
    // 72 BPM the click fell ~70 ms behind after 3 minutes.
    final endMs = startMs + durationMs;
    int positionOf(int n) => (n * 60000 / config.bpm).round();

    // First pulse at or after startMs, on the global beat grid.
    var n = (startMs * config.bpm / 60000).floor();
    while (positionOf(n) < startMs) {
      n++;
    }

    final pulses = <MetronomePulse>[];
    while (positionOf(n) < endMs) {
      pulses.add(MetronomePulse(
        positionMs: positionOf(n),
        isDownbeat: n % config.beatsPerMeasure == 0,
      ));
      n++;
    }

    return pulses;
  }
}
