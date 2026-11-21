import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/audio/audio_playback_engine.dart';
import '../../infrastructure/audio/multi_track_audio_engine.dart';

/// First Riverpod provider for the audio engine — until now
/// `MultiTrackAudioEngine` was only ever instantiated manually by
/// `BackgroundAudioHandler`, outside the provider tree.
final audioPlaybackEngineProvider = Provider<AudioPlaybackEngine>((ref) {
  final engine = MultiTrackAudioEngine();
  ref.onDispose(engine.dispose);
  return engine;
});
