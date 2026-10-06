import 'ids.dart';

enum RoomLifecycle { advertising, ended }

class Room {
  final RoomId id;
  final String code;
  final DeviceId masterId;
  final RoomLifecycle state;

  const Room({
    required this.id,
    required this.code,
    required this.masterId,
    required this.state,
  });

  Room copyWith({RoomLifecycle? state}) {
    return Room(
      id: id,
      code: code,
      masterId: masterId,
      state: state ?? this.state,
    );
  }
}
