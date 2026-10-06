import 'dart:async';

import 'package:nsd/nsd.dart' as nsd;

import 'package:cantae/domain/session/ids.dart';
import 'package:cantae/domain/session/room_discovery.dart';

class NsdRoomDiscovery implements RoomDiscovery {
  static const serviceType = '_cantae._tcp';

  nsd.Registration? _registration;

  @override
  Future<void> advertise(RoomId id, int port) async {
    _registration = await nsd.register(
      nsd.Service(name: id.value, type: serviceType, port: port),
    );
  }

  @override
  Future<void> stopAdvertising() async {
    final registration = _registration;
    if (registration == null) {
      return;
    }
    await nsd.unregister(registration);
    _registration = null;
  }

  @override
  Stream<DiscoveredRoom> discover() {
    nsd.Discovery? discovery;
    late StreamController<DiscoveredRoom> controller;

    void onServiceEvent(nsd.Service service, nsd.ServiceStatus status) {
      if (status != nsd.ServiceStatus.found) {
        return;
      }
      final name = service.name;
      final host = service.host;
      final port = service.port;
      if (name == null || host == null || port == null) {
        return;
      }
      controller.add(DiscoveredRoom(id: RoomId(name), host: host, port: port));
    }

    controller = StreamController<DiscoveredRoom>(
      onListen: () async {
        discovery = await nsd.startDiscovery(serviceType);
        discovery!.addServiceListener(onServiceEvent);
      },
      onCancel: () async {
        final activeDiscovery = discovery;
        if (activeDiscovery == null) {
          return;
        }
        activeDiscovery.removeServiceListener(onServiceEvent);
        await nsd.stopDiscovery(activeDiscovery);
      },
    );
    return controller.stream;
  }
}
