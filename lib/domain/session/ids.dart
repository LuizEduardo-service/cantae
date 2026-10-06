class RoomId {
  final String value;

  const RoomId(this.value);

  @override
  bool operator ==(Object other) => other is RoomId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

class DeviceId {
  final String value;

  const DeviceId(this.value);

  @override
  bool operator ==(Object other) => other is DeviceId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

class ParticipantId {
  final String value;

  const ParticipantId(this.value);

  @override
  bool operator ==(Object other) =>
      other is ParticipantId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
