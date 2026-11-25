/// What the OS says about audio focus, reduced to what a player needs
/// (background-audio BGA-11/12/13).
enum AudioInterruption {
  /// A call or another app took the audio; playback must pause.
  pauseBegan,

  /// That interruption is over. It never means "resume": playback only
  /// resumes when the person asks.
  pauseEnded,

  /// Another app plays a short sound; lower the volume meanwhile.
  duckBegan,

  /// The short sound is over; restore the volume.
  duckEnded,

  /// Headphones were unplugged or disconnected; playback must pause.
  headphonesDisconnected,
}

/// Source of [AudioInterruption]s.
abstract class AudioInterruptions {
  Stream<AudioInterruption> get events;
}

/// Default when no OS source is wired (tests, or the session failed to
/// start): never emits.
class NoAudioInterruptions implements AudioInterruptions {
  const NoAudioInterruptions();

  @override
  Stream<AudioInterruption> get events => const Stream.empty();
}
