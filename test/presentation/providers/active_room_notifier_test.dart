import 'package:cantae/data/session/room_session_controller.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/session/handshake_service.dart';
import 'package:cantae/domain/session/ids.dart';
import 'package:cantae/domain/session/participant_session.dart';
import 'package:cantae/domain/session/room_discovery.dart';
import 'package:cantae/domain/session/room_entry_rules.dart';
import 'package:cantae/infrastructure/network/tcp_session_transport.dart';
import 'package:cantae/presentation/providers/active_room_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/room_fakes.dart';

// Failure modes (ROOM-17, 31, 41, 43, 47):
// - a device hosts a room and joins another at the same time;
// - a room that failed to start stays as the active room;
// - joining gets in but the active room is not the joined one, or keeps
//   the wrong master name;
// - a refusal still makes the room active;
// - closing as host leaves the room announced and the singers connected;
// - closing as member leaves the singer listed on the master's screen.
class _Device {
  _Device(RoomBus bus, String id)
      : discovery = InMemoryRoomDiscovery(bus),
        profiles = InMemoryLocalProfiles(id) {
    notifier = ActiveRoomNotifier(
      newController: (self) => RoomSessionController(
        transport: TcpSessionTransport(),
        discovery: discovery,
        handshakeService: HandshakeService(),
        selfDeviceId: self,
      ),
      profiles: profiles,
    );
  }

  final InMemoryRoomDiscovery discovery;
  final InMemoryLocalProfiles profiles;
  late final ActiveRoomNotifier notifier;
}

void main() {
  late RoomBus bus;
  final devices = <_Device>[];

  _Device device(String id) {
    final d = _Device(bus, id);
    devices.add(d);
    return d;
  }

  setUp(() => bus = RoomBus());
  tearDown(() async {
    for (final d in devices) {
      d.notifier.dispose();
    }
    devices.clear();
    await bus.close();
  });

  Future<ActiveRoom> host(_Device d) async => (await d.notifier
          .host(masterName: 'Marina', songName: 'Ave Verum Corpus'))
      .when(success: (r) => r, failure: (f) => fail(f.code));

  Future<DiscoveredRoom> firstRoom(_Device d) async {
    final search = (await d.notifier.search())
        .when(success: (s) => s, failure: (f) => fail(f.code));
    return search
        .firstWhere((r) => r.available)
        .timeout(const Duration(seconds: 5));
  }

  /// Approves the first pending request on [master] once it shows up.
  Future<void> approveNext(ActiveRoom master) async {
    final snapshot = await master.controller.snapshots
        .firstWhere((s) => s.participants
            .any((p) => p.state == ParticipantState.pendingApproval))
        .timeout(const Duration(seconds: 5));
    await master.controller.approve(snapshot.participants
        .firstWhere((p) => p.state == ParticipantState.pendingApproval)
        .id);
  }

  test('hosting makes a host room with a 4-digit code (ROOM-17)', () async {
    final marina = device('marina');

    final room = await host(marina);

    expect(marina.notifier.state, same(room));
    expect(room.role, RoomRole.host);
    expect(room.code, matches(RegExp(r'^\d{4}$')));
    expect(room.masterName, 'Marina');
    expect(room.songName, 'Ave Verum Corpus');
  });

  test('a room that fails to start is not active', () async {
    final marina = device('marina');
    marina.discovery.advertiseResult =
        Result.failure(NetworkFailure(code: 'discovery.permission-denied'));

    final result = await marina.notifier.host(masterName: 'Marina');

    expect(result.when(success: (_) => null, failure: (f) => f.code),
        'discovery.permission-denied');
    expect(marina.notifier.state, isNull);
  });

  test('searching closes the hosted room first (ROOM-47)', () async {
    final marina = device('marina');
    await host(marina);

    await marina.notifier.search();

    expect(marina.notifier.state, isNull);
    expect(marina.discovery.stops, 1);
  });

  test(
      'an approved request makes the joined room active, with its master '
      '(ROOM-31)', () async {
    final marina = device('marina');
    final ana = device('ana');
    final hosted = await host(marina);
    final room = await firstRoom(ana);

    final outcome = ana.notifier.join(room, hosted.code!, displayName: 'Ana');
    await approveNext(hosted);

    expect(
        await outcome.timeout(const Duration(seconds: 5)), JoinOutcome.joined);
    final active = ana.notifier.state!;
    expect(active.role, RoomRole.member);
    expect(active.roomId, hosted.roomId);
    expect(active.masterName, 'Marina');
    expect(active.songName, 'Ave Verum Corpus');
  });

  test('a refused request leaves no active room', () async {
    final marina = device('marina');
    final ana = device('ana');
    final hosted = await host(marina);
    final room = await firstRoom(ana);

    final wrongCode = hosted.code == '0000' ? '1111' : '0000';

    final outcome = ana.notifier.join(room, wrongCode, displayName: 'Ana');

    expect(await outcome.timeout(const Duration(seconds: 5)),
        JoinOutcome.invalidCode);
    expect(ana.notifier.state, isNull);
  });

  test('closing as host ends the room for everyone (ROOM-41)', () async {
    final marina = device('marina');
    final ana = device('ana');
    final hosted = await host(marina);
    final room = await firstRoom(ana);
    final outcome = ana.notifier.join(room, hosted.code!, displayName: 'Ana');
    await approveNext(hosted);
    await outcome;
    final lost = ana.notifier.state!.controller.masterConnectionLost.first;

    await marina.notifier.close();

    expect(marina.notifier.state, isNull);
    expect(marina.discovery.stops, 1);
    await lost.timeout(const Duration(seconds: 5));
  });

  test('closing as member drops the singer from the room (ROOM-43)', () async {
    final marina = device('marina');
    final ana = device('ana');
    final hosted = await host(marina);
    final room = await firstRoom(ana);
    final outcome = ana.notifier.join(room, hosted.code!, displayName: 'Ana');
    await approveNext(hosted);
    await outcome;
    final dropped = hosted.controller.snapshots.firstWhere((s) =>
        s.participants.any((p) => p.state == ParticipantState.disconnected));

    await ana.notifier.close();

    expect(ana.notifier.state, isNull);
    await dropped.timeout(const Duration(seconds: 5));
  });

  test('the device id comes from the local profile (ROOM-48)', () async {
    final marina = device('marina-device');
    final ana = device('ana-device');
    final hosted = await host(marina);
    final room = await firstRoom(ana);

    final outcome = ana.notifier.join(room, hosted.code!, displayName: 'Ana');
    final snapshot = await hosted.controller.snapshots
        .firstWhere((s) => s.participants.isNotEmpty)
        .timeout(const Duration(seconds: 5));

    expect(snapshot.participants.single.id, const ParticipantId('ana-device'));
    expect(snapshot.participants.single.displayName, 'Ana');
    await ana.notifier.cancelJoin();
    expect(await outcome, JoinOutcome.cancelled);
  });
}
