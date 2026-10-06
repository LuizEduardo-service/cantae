import 'dart:typed_data';

import 'ids.dart';

abstract class SessionTransport {
  Future<void> listen(int port);

  int get boundPort;

  Future<ParticipantId> connect(String host, int port);

  Stream<ParticipantId> get incomingConnections;

  Stream<ParticipantId> get closedConnections;

  Stream<Uint8List> receive(ParticipantId id);

  Future<void> send(ParticipantId id, Uint8List bytes);

  Future<void> close(ParticipantId id);
}
