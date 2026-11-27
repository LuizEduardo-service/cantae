/// This device as rooms see it (AD-014): a stable [deviceId] for the
/// transport and the [displayName] shown to other people, once chosen.
class LocalProfile {
  final String deviceId;
  final String? displayName;

  const LocalProfile({required this.deviceId, this.displayName});
}
