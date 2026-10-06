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

    final intervalMs = 60000 ~/ config.bpm;
    final endMs = startMs + durationMs;

    // First beat at or after startMs, aligned to the global beat grid
    final firstBeat = startMs == 0
        ? 0
        : ((startMs + intervalMs - 1) ~/ intervalMs) * intervalMs;

    final pulses = <MetronomePulse>[];
    var beatIndex = firstBeat ~/ intervalMs;
    var positionMs = firstBeat;

    while (positionMs < endMs) {
      pulses.add(MetronomePulse(
        positionMs: positionMs,
        isDownbeat: beatIndex % config.beatsPerMeasure == 0,
      ));
      beatIndex++;
      positionMs += intervalMs;
    }

    return pulses;
  }
}
