import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:cantae/domain/audio/click_track_builder.dart';
import 'package:cantae/domain/audio/metronome_pulse_generator.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/entities/metronome_config.dart';
import 'package:cantae/infrastructure/audio/click_track_wav.dart';

/// Writes the click track as `metronome_<songId>.wav` in the app's temporary
/// directory, overwriting the previous one. The WAV is synthesized in a
/// separate isolate so a long song never blocks the UI thread (CLAUDE.md).
class FileClickTrackBuilder implements ClickTrackBuilder {
  FileClickTrackBuilder({Future<Directory> Function()? directory})
      : _directory = directory ?? getTemporaryDirectory;

  final Future<Directory> Function() _directory;

  @override
  Future<Result<String, Failure>> build({
    required String songId,
    required MetronomeConfig config,
    required int durationMs,
  }) async {
    try {
      final directory = await _directory();
      final bpm = config.bpm;
      final beatsPerMeasure = config.beatsPerMeasure;
      final accent = config.downbeatAccent;
      final bytes = await Isolate.run(
        () => _encode(bpm, beatsPerMeasure, accent, durationMs),
      );
      final file = File(p.join(directory.path, 'metronome_$songId.wav'));
      await file.writeAsBytes(bytes, flush: true);
      return Result.success(file.path);
    } catch (_) {
      // Disk full, missing directory, isolate failure: infrastructure
      // exceptions become a typed failure (AD-002).
      return Result.failure(
        PlaybackFailure(code: 'click_track_build_failed'),
      );
    }
  }
}

Uint8List _encode(
  int bpm,
  int beatsPerMeasure,
  bool accent,
  int durationMs,
) {
  final pulses = MetronomePulseGenerator.generate(
    startMs: 0,
    durationMs: durationMs,
    config: MetronomeConfig(bpm: bpm, beatsPerMeasure: beatsPerMeasure),
  );
  return ClickTrackWav.encode(
    pulses: accent
        ? pulses
        : [
            for (final pulse in pulses)
              MetronomePulse(positionMs: pulse.positionMs, isDownbeat: false),
          ],
    durationMs: durationMs,
  );
}
