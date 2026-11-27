import '../core/failures.dart';
import '../core/result.dart';
import '../core/unit.dart';
import 'ids.dart';
import 'room_entry_rules.dart';

/// What a room tells the Wi‑Fi about itself. Never the 4-digit code nor
/// any key material (NET-01): the code proves the singer sees the master's
/// screen.
class RoomAnnouncement {
  final String masterName;
  final String? songName;
  final int protocolVersion;

  const RoomAnnouncement({
    required this.masterName,
    this.songName,
    this.protocolVersion = roomProtocolVersion,
  });
}

class DiscoveredRoom {
  final RoomId id;
  final String host;
  final int port;
  final String masterName;
  final String? songName;
  final int protocolVersion;

  /// `false` when the room stopped announcing itself (it closed or left
  /// the network).
  final bool available;

  const DiscoveredRoom({
    required this.id,
    required this.host,
    required this.port,
    this.masterName = '',
    this.songName,
    this.protocolVersion = roomProtocolVersion,
    this.available = true,
  });
}

abstract class RoomDiscovery {
  /// Fails with `discovery.permission-denied` when the system refuses local
  /// network access, or `discovery.failed` otherwise.
  Future<Result<Unit, NetworkFailure>> advertise(
    RoomId id,
    int port,
    RoomAnnouncement announcement,
  );

  /// Errors on the stream are [NetworkFailure]s with the same codes.
  Stream<DiscoveredRoom> discover();

  Future<void> stopAdvertising();
}
