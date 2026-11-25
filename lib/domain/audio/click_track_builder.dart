import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/entities/metronome_config.dart';

/// Prepares the metronome's click track for a song: an audio file as long
/// as the song, with a click on every beat of [MetronomeConfig]. The engine
/// plays it as one more track, so it stays on the shared timeline.
abstract class ClickTrackBuilder {
  /// Returns the path of the click track file, or a failure. Never throws.
  Future<Result<String, Failure>> build({
    required String songId,
    required MetronomeConfig config,
    required int durationMs,
  });
}
