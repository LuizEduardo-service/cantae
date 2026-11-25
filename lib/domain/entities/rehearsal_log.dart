/// How a rehearsal happened (PRD `RehearsalLog.mode`).
enum RehearsalMode { solo, room }

/// This device's role in a room rehearsal (PRD `RehearsalLog.localRole`).
enum RehearsalRole { master, singer, visitor }

/// One recorded rehearsal (PRD "Histórico de ensaios"). Holds only these
/// fields: no audio, lyrics or data about other people (HIST-06).
class RehearsalLog {
  final String id;
  final String songId;
  final DateTime startedAt;
  final DateTime endedAt;

  /// Time with the music playing, not time on the screen.
  final int durationMs;
  final RehearsalMode mode;

  /// Null in Modo solo, which has no room role.
  final RehearsalRole? localRole;
  final int maxParticipants;

  /// Times the loop jumped back to the start of its section.
  final int loopCount;

  const RehearsalLog({
    required this.id,
    required this.songId,
    required this.startedAt,
    required this.endedAt,
    required this.durationMs,
    required this.mode,
    this.localRole,
    required this.maxParticipants,
    required this.loopCount,
  })  : assert(id.length > 0, 'RehearsalLog.id must not be empty'),
        assert(songId.length > 0, 'RehearsalLog.songId must not be empty'),
        assert(durationMs >= 0, 'RehearsalLog.durationMs must not be negative'),
        assert(loopCount >= 0, 'RehearsalLog.loopCount must not be negative');
}
