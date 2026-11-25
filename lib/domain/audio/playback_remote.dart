/// What the lock screen and the notification show (background-audio
/// BGA-05/06).
class NowPlaying {
  const NowPlaying({
    required this.title,
    required this.subtitle,
    required this.durationMs,
    required this.playing,
    required this.positionMs,
  });

  final String title;
  final String subtitle;
  final int durationMs;
  final bool playing;
  final int positionMs;
}

/// A transport command from the lock screen or the notification.
sealed class RemoteCommand {
  const RemoteCommand();
}

class RemotePlay extends RemoteCommand {
  const RemotePlay();
}

class RemotePause extends RemoteCommand {
  const RemotePause();
}

class RemoteSeek extends RemoteCommand {
  const RemoteSeek(this.positionMs);

  final int positionMs;
}

/// Stop and leave: the notification is dismissed or the app is closed from
/// the recents list.
class RemoteStop extends RemoteCommand {
  const RemoteStop();
}

/// Publishes what is playing to the OS and receives its commands.
abstract class PlaybackRemote {
  void publish(NowPlaying info);

  /// Nothing is loaded: the notification goes away.
  void clear();

  Stream<RemoteCommand> get commands;
}

/// Default when the OS service is not available (tests, or it failed to
/// start): publishes nowhere and never commands (BGA-18).
class NoPlaybackRemote implements PlaybackRemote {
  const NoPlaybackRemote();

  @override
  void publish(NowPlaying info) {}

  @override
  void clear() {}

  @override
  Stream<RemoteCommand> get commands => const Stream.empty();
}
