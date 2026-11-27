import 'dart:convert';
import 'dart:typed_data';

import 'package:cantae/domain/core/failures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsd_platform_interface/nsd_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:cantae/domain/session/ids.dart';
import 'package:cantae/domain/session/room_discovery.dart';
import 'package:cantae/infrastructure/network/nsd_room_discovery.dart';

class _FakeNsdPlatform extends NsdPlatformInterface
    with MockPlatformInterfaceMixin {
  Service? registeredService;
  Registration? unregisteredRegistration;
  String? discoveredServiceType;
  Discovery? lastDiscovery;
  var _discoveryCounter = 0;
  Object? registerError;
  Object? discoveryError;

  @override
  Future<Registration> register(Service service) async {
    if (registerError != null) throw registerError!;
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
    if (discoveryError != null) throw discoveryError!;
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

const _announcement = RoomAnnouncement(masterName: 'Marina');

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

      await discovery.advertise(const RoomId('room-456'), 5001, _announcement);

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

      await discovery.advertise(const RoomId('room-456'), 5001, _announcement);

      // NET-01: "advertise it ... with a service name, a random room ID, and
      // no embedded secret." advertise()'s signature never accepts a code at
      // all, so this is a structural guarantee, not just a runtime check —
      // this test documents and locks that guarantee. room-entry (D7) adds
      // the master's name, song and protocol version to the TXT record;
      // nothing else may go there.
      expect(fakePlatform.registeredService!.txt!.keys.toSet(), {'m', 'v'});
    });
  });

  group('NsdRoomDiscovery.stopAdvertising', () {
    test('unregisters the active registration', () async {
      final discovery = NsdRoomDiscovery();
      await discovery.advertise(const RoomId('room-789'), 6000, _announcement);

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

  // Failure modes (ROOM-20, 23, 37, NET-01): the announcement loses the
  // master or the song on the way; a long song name breaks the TXT limit
  // or an accented character; an older app's room (no TXT) is dropped or
  // shows an empty name; a room that left stays on the list; a denied
  // local network permission looks like any other error.
  group('announcement mapping', () {
    Service service({Map<String, Uint8List?>? txt}) => Service(
          name: 'room-1',
          type: NsdRoomDiscovery.serviceType,
          host: '192.168.1.5',
          port: 5000,
          txt: txt,
        );

    test('master, song and version survive the TXT record', () {
      final txt = announcementToTxt(const RoomAnnouncement(
        masterName: 'Marina Conceição',
        songName: 'Ave Verum Corpus',
        protocolVersion: 3,
      ));

      final room = discoveredRoomFrom(service(txt: txt), ServiceStatus.found)!;

      expect(room.masterName, 'Marina Conceição');
      expect(room.songName, 'Ave Verum Corpus');
      expect(room.protocolVersion, 3);
      expect(room.available, isTrue);
      expect(txt.keys.toSet(), {'m', 's', 'v'});
    });

    test('a 300-byte song name is cut to fit, on a character boundary', () {
      final song = 'ç' * 150; // 300 bytes in UTF-8
      final txt = announcementToTxt(
        RoomAnnouncement(masterName: 'Marina', songName: song),
      );

      final bytes = txt['s']!;
      expect(bytes.length + 's='.length, lessThanOrEqualTo(255));
      final decoded = utf8.decode(bytes);
      expect(song.startsWith(decoded), isTrue);
      expect(decoded, isNotEmpty);
    });

    test('a room without TXT (older app) is listed as "Sem nome", version 0',
        () {
      final room = discoveredRoomFrom(service(), ServiceStatus.found)!;

      expect(room.masterName, 'Sem nome');
      expect(room.songName, isNull);
      expect(room.protocolVersion, 0);
    });

    test('a lost room is reported as unavailable', () {
      final room = discoveredRoomFrom(
        const Service(name: 'room-1', type: NsdRoomDiscovery.serviceType),
        ServiceStatus.lost,
      )!;

      expect(room.id, const RoomId('room-1'));
      expect(room.available, isFalse);
    });

    test('a denied permission and any other error get their own codes', () {
      expect(
        discoveryFailureFor(NsdError(ErrorCause.securityIssue, 'denied')).code,
        'discovery.permission-denied',
      );
      expect(
        discoveryFailureFor(NsdError(ErrorCause.internalError, 'boom')).code,
        'discovery.failed',
      );
      expect(discoveryFailureFor(StateError('x')).code, 'discovery.failed');
    });

    test('advertise reports a refused registration as a failure', () async {
      fakePlatform.registerError = NsdError(ErrorCause.securityIssue, 'denied');

      final result = await NsdRoomDiscovery()
          .advertise(const RoomId('room-1'), 5000, _announcement);

      expect(
        result.when(success: (_) => null, failure: (Failure f) => f.code),
        'discovery.permission-denied',
      );
    });

    test('discover reports a refused discovery on the stream', () async {
      fakePlatform.discoveryError =
          NsdError(ErrorCause.securityIssue, 'denied');

      final error = await NsdRoomDiscovery()
          .discover()
          .first
          .then<Object?>((_) => null, onError: (Object e) => e)
          .timeout(const Duration(seconds: 5));

      expect(error, isA<NetworkFailure>());
      expect((error! as NetworkFailure).code, 'discovery.permission-denied');
    });
  });
}
