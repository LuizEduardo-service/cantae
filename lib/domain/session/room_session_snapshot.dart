import 'participant_session.dart';
import 'room.dart';

class RoomSessionSnapshot {
  final Room room;
  final List<ParticipantSession> participants;

  const RoomSessionSnapshot({required this.room, required this.participants});
}
