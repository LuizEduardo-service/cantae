import 'package:flutter_test/flutter_test.dart';
import 'package:nsd_platform_interface/nsd_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:cantae/domain/session/ids.dart';
import 'package:cantae/infrastructure/network/nsd_room_discovery.dart';

class _FakeNsdPlatform extends NsdPlatformInterface
    with MockPlatformInterfaceMixin {
  Service? registeredService;
  Registration? unregisteredRegistration;
  String? discoveredServiceType;
  Discovery? lastDiscovery;
  var _discoveryCounter = 0;

  @override
  Future<Registration> register(Service service) async {
    registeredService = service;
    return Registration('reg-${service.name}', service);
  }

  @override
  Future<void> unregister(Registration registration) async {
    unregisteredRegistration = registration;
  }

  @override
  Future<Discovery> startDiscovery(
    String serviceType, {
    bool autoResolve = true,
    IpLookupType ipLookupType = IpLookupType.none,
  }) async {
    discoveredServiceType = serviceType;
    final discovery = Discovery('disc-${_discoveryCounter++}');
    lastDiscovery = discovery;
    return discovery;
  }

  @override
  Future<void> stopDiscovery(Discovery discovery) async {}

  @override
  Future<Service> resolve(Service service) async => service;

  @override
  void enableLogging(LogTopic logTopic) {}

  @override
  void disableServiceTypeValidation(bool value) {}
}

void main() {
  late _FakeNsdPlatform fakePlatform;

  setUp(() {
    fakePlatform = _FakeNsdPlatform();
    NsdPlatformInterface.instance = fakePlatform;
  });

  group('NsdRoomDiscovery.advertise', () {
    test(
        'registers a service using the project service type, room id, and given port',
        () async {
      final discovery = NsdRoomDiscovery();

      await discovery.advertise(const RoomId('room-456'), 5001);

      expect(fakePlatform.registeredService!.name, equals('room-456'));
      expect(
        fakePlatform.registeredService!.type,
        equals(NsdRoomDiscovery.serviceType),
      );
      expect(fakePlatform.registeredService!.port, equals(5001));
    });

    test(
        'never embeds a secret: advertise() has no code parameter, and the registered service carries no txt records (NET-01)',
        () async {
      final discovery = NsdRoomDiscovery();

      await discovery.advertise(const RoomId('room-456'), 5001);

      // NET-01: "advertise it ... with a service name, a random room ID, and
      // no embedded secret." advertise()'s signature never accepts a code at
      // all, so this is a structural guarantee, not just a runtime check —
      // this test documents and locks that guarantee.
      expect(fakePlatform.registeredService!.txt, isNull);
    });
  });

  group('NsdRoomDiscovery.stopAdvertising', () {
    test('unregisters the active registration', () async {
      final discovery = NsdRoomDiscovery();
      await discovery.advertise(const RoomId('room-789'), 6000);

      await discovery.stopAdvertising();

      expect(
        fakePlatform.unregisteredRegistration!.id,
        equals('reg-room-789'),
      );
    });
  });

  group('NsdRoomDiscovery.discover', () {
    test(
        'starts discovery with the project service type and maps a found service to DiscoveredRoom',
        () async {
      final discovery = NsdRoomDiscovery();

      final roomFuture = discovery.discover().first;
      await Future.delayed(Duration.zero);
      expect(fakePlatform.discoveredServiceType,
          equals(NsdRoomDiscovery.serviceType));

      fakePlatform.lastDiscovery!.add(
        const Service(
          name: 'room-123',
          type: NsdRoomDiscovery.serviceType,
          host: '192.168.1.5',
          port: 5000,
        ),
      );

      final room = await roomFuture.timeout(const Duration(seconds: 5));
      expect(room.id, equals(const RoomId('room-123')));
      expect(room.host, equals('192.168.1.5'));
      expect(room.port, equals(5000));
    });
  });
}
