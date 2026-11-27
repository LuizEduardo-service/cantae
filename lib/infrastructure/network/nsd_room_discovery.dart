import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nsd/nsd.dart' as nsd;

import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/core/unit.dart';
import 'package:cantae/domain/session/ids.dart';
import 'package:cantae/domain/session/room_discovery.dart';
import 'package:cantae/domain/session/room_entry_rules.dart';

/// A TXT entry is `key=value` in at most 255 bytes.
const int _txtEntryMaxBytes = 255;

/// The TXT record of a room: `m` master name, `s` song, `v` protocol
/// version. Never the code nor key material (NET-01).
Map<String, Uint8List?> announcementToTxt(RoomAnnouncement announcement) => {
      'm': _cutUtf8(announcement.masterName, _txtEntryMaxBytes - 2),
      if (announcement.songName case final song?)
        's': _cutUtf8(song, _txtEntryMaxBytes - 2),
      'v': Uint8List.fromList(utf8.encode('${announcement.protocolVersion}')),
    };

/// Maps an mDNS event to a room, or null when the service is unusable.
/// Names from the network are cleaned before they reach the screen.
DiscoveredRoom? discoveredRoomFrom(
    nsd.Service service, nsd.ServiceStatus status) {
  final name = service.name;
  if (name == null) return null;
  if (status == nsd.ServiceStatus.lost) {
    return DiscoveredRoom(
        id: RoomId(name), host: '', port: 0, available: false);
  }
  final host = service.host;
  final port = service.port;
  if (host == null || port == null) return null;
  final txt = service.txt ?? const {};
  final song = _text(txt['s'])
      ?.replaceAll(RegExp(r'[\u0000-\u001F\u007F-\u009F]'), '')
      .trim();
  return DiscoveredRoom(
    id: RoomId(name),
    host: host,
    port: port,
    masterName: sanitizeRemoteDisplayName(_text(txt['m']) ?? ''),
    songName: (song == null || song.isEmpty) ? null : song,
    protocolVersion: int.tryParse(_text(txt['v']) ?? '') ?? 0,
  );
}

/// `discovery.permission-denied` when the system refused local network
/// access, `discovery.failed` for anything else.
NetworkFailure discoveryFailureFor(Object error) => NetworkFailure(
      code: error is nsd.NsdError && error.cause == nsd.ErrorCause.securityIssue
          ? 'discovery.permission-denied'
          : 'discovery.failed',
    );

String? _text(Uint8List? bytes) =>
    bytes == null ? null : utf8.decode(bytes, allowMalformed: true);

Uint8List _cutUtf8(String value, int maxBytes) {
  final out = BytesBuilder();
  for (final rune in value.runes) {
    final bytes = utf8.encode(String.fromCharCode(rune));
    if (out.length + bytes.length > maxBytes) break;
    out.add(bytes);
  }
  return out.toBytes();
}

class NsdRoomDiscovery implements RoomDiscovery {
  static const serviceType = '_cantae._tcp';

  nsd.Registration? _registration;

  @override
  Future<Result<Unit, NetworkFailure>> advertise(
    RoomId id,
    int port,
    RoomAnnouncement announcement,
  ) async {
    try {
      _registration = await nsd.register(
        nsd.Service(
          name: id.value,
          type: serviceType,
          port: port,
          txt: announcementToTxt(announcement),
        ),
      );
      return const Result.success(Unit());
    } on Object catch (error) {
      return Result.failure(discoveryFailureFor(error));
    }
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
      final room = discoveredRoomFrom(service, status);
      if (room != null) controller.add(room);
    }

    controller = StreamController<DiscoveredRoom>(
      onListen: () async {
        try {
          discovery = await nsd.startDiscovery(serviceType);
          discovery!.addServiceListener(onServiceEvent);
        } on Object catch (error) {
          controller.addError(discoveryFailureFor(error));
        }
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
