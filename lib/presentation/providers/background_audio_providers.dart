import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/audio/audio_interruptions.dart';
import '../../domain/audio/playback_remote.dart';

/// Lock screen and notification (background-audio). `main.dart` overrides
/// it with the registered `audio_service` handler; elsewhere it is a no-op.
final playbackRemoteProvider = Provider<PlaybackRemote>(
  (ref) => const NoPlaybackRemote(),
);

/// OS audio interruptions. `main.dart` overrides it with the audio session's
/// events; elsewhere it never emits.
final audioInterruptionsProvider = Provider<AudioInterruptions>(
  (ref) => const NoAudioInterruptions(),
);
