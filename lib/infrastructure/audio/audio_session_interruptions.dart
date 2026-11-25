import 'dart:async';

import 'package:audio_session/audio_session.dart';

import '../../domain/audio/audio_interruptions.dart';

/// Maps `audio_session`'s interruption and becoming-noisy streams to
/// [AudioInterruption] (background-audio design, `AudioSessionInterruptions`).
class AudioSessionInterruptions implements AudioInterruptions {
  AudioSessionInterruptions({
    required Stream<AudioInterruptionEvent> interruptions,
    required Stream<void> becomingNoisy,
  }) {
    _subscriptions = [
      interruptions.listen(_onInterruption),
      becomingNoisy
          .listen((_) => _events.add(AudioInterruption.headphonesDisconnected)),
    ];
  }

  static Future<AudioSessionInterruptions> fromSession(
    AudioSession session,
  ) async =>
      AudioSessionInterruptions(
        interruptions: session.interruptionEventStream,
        becomingNoisy: session.becomingNoisyEventStream,
      );

  final _events = StreamController<AudioInterruption>.broadcast();
  late final List<StreamSubscription<Object?>> _subscriptions;

  @override
  Stream<AudioInterruption> get events => _events.stream;

  void _onInterruption(AudioInterruptionEvent event) {
    final mapped = switch ((event.begin, event.type)) {
      (true, AudioInterruptionType.duck) => AudioInterruption.duckBegan,
      (false, AudioInterruptionType.duck) => AudioInterruption.duckEnded,
      (true, _) => AudioInterruption.pauseBegan,
      (false, AudioInterruptionType.pause) => AudioInterruption.pauseEnded,
      // The end of an "unknown" (possibly permanent) loss carries no promise
      // that the audio is free again.
      (false, AudioInterruptionType.unknown) => null,
    };
    if (mapped != null) _events.add(mapped);
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _events.close();
  }
}
