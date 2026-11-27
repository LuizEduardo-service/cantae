import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/drift_local_profile_repository.dart';
import '../../data/session/room_session_controller.dart';
import '../../domain/entities/local_profile.dart';
import '../../domain/repositories/local_profile_repository.dart';
import '../../domain/session/handshake_service.dart';
import '../../domain/session/ids.dart';
import '../../domain/session/room_discovery.dart';
import '../../domain/session/session_transport.dart';
import '../../domain/session/system_settings.dart';
import '../../infrastructure/network/nsd_room_discovery.dart';
import '../../infrastructure/network/tcp_session_transport.dart';
import '../../infrastructure/platform/method_channel_system_settings.dart';
import 'song_repository_provider.dart';

/// mDNS on the device. Overridden in tests with an in-memory bus.
final roomDiscoveryProvider =
    Provider<RoomDiscovery>((ref) => NsdRoomDiscovery());

/// A fresh transport per room controller. Overridden in tests.
final sessionTransportFactoryProvider =
    Provider<SessionTransport Function()>((ref) => TcpSessionTransport.new);

final handshakeServiceProvider =
    Provider<HandshakeService>((ref) => HandshakeService());

/// Builds the controller for one room, as this device.
final roomControllerFactoryProvider =
    Provider<RoomSessionController Function(DeviceId self)>((ref) {
  final discovery = ref.watch(roomDiscoveryProvider);
  final transport = ref.watch(sessionTransportFactoryProvider);
  final handshake = ref.watch(handshakeServiceProvider);
  return (self) => RoomSessionController(
        transport: transport(),
        discovery: discovery,
        handshakeService: handshake,
        selfDeviceId: self,
      );
});

/// "Abrir ajustes" (ROOM-20, ROOM-37, ROOM-57). Overridden in tests.
final systemSettingsProvider =
    Provider<SystemSettings>((ref) => const MethodChannelSystemSettings());

final localProfileRepositoryProvider = Provider<LocalProfileRepository>(
  (ref) => DriftLocalProfileRepository(ref.watch(appDatabaseProvider)),
);

/// The device profile; refreshed after the name is saved.
final localProfileProvider = FutureProvider<LocalProfile>((ref) async {
  final result = await ref.watch(localProfileRepositoryProvider).load();
  return result.when(success: (p) => p, failure: (f) => throw f);
});
