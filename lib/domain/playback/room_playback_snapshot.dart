enum PlaybackPhase { idle, waiting, scheduled, playing, paused }

final class RoomPlaybackSnapshot {
  final String? activeSongId;
  final PlaybackPhase phase;
  final DateTime? scheduledStartAt; // only set while phase == scheduled

  const RoomPlaybackSnapshot({
    required this.activeSongId,
    required this.phase,
    required this.scheduledStartAt,
  });
}
