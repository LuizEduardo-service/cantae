/// Opens this app's page in the system settings, where the person can
/// allow local network access (ROOM-20, ROOM-37, ROOM-57).
abstract class SystemSettings {
  Future<void> openAppSettings();
}
