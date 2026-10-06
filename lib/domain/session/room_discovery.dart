import 'ids.dart';

class DiscoveredRoom {
  final RoomId id;
  final String host;
  final int port;

  const DiscoveredRoom(
      {required this.id, required this.host, required this.port});
}

abstract class RoomDiscovery {
  Future<void> advertise(RoomId id, int port);

  Stream<DiscoveredRoom> discover();

  Future<void> stopAdvertising();
}
