import 'package:cantae/data/session/room_session_controller.dart';
import 'package:cantae/domain/session/handshake_service.dart';
import 'package:cantae/domain/session/ids.dart';
import 'package:cantae/domain/session/participant_session.dart';
import 'package:cantae/domain/session/room_entry_rules.dart';
import 'package:cantae/infrastructure/network/tcp_session_transport.dart';
import 'package:cantae/presentation/providers/active_room_notifier.dart';
import 'package:cantae/presentation/providers/member_room_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/room_fakes.dart';

// Failure modes (ROOM-42..44): the singer's room shows the wrong master or
// song; the master ending the room is not noticed, or the dead room stays
// active; "Sair da sala" leaves the singer listed on the master's screen;
// the screen opens with no room and shows nothing useful.
void main() {
  late RoomBus bus;
  late RoomSessionController master;
  late ProviderContainer container;

  RoomSessionController controller(DeviceId self) => RoomSessionController(
        transport: TcpSessionTransport(),
        discovery: InMemoryRoomDiscovery(bus),
        handshakeService: HandshakeService(),
        selfDeviceId: self,
      );

  setUp(() {
    bus = RoomBus();
    master = controller(const DeviceId('marina'));
    container = ProviderContainer(overrides: [
      activeRoomProvider.overrideWith((ref) => ActiveRoomNotifier(
            newController: controller,
            profiles: InMemoryLocalProfiles('ana'),
          )),
    ]);
  });

  tearDown(() async {
    container.dispose();
    master.dispose();
    await bus.close();
  });

  /// Ana joins Marina's room through the real notifier.
  Future<void> joinMarina() async {
    await master.createRoom(masterName: 'Marina', songName: 'Ave Verum');
    final rooms = container.read(activeRoomProvider.notifier);
    final search = (await rooms.search())
        .when(success: (s) => s, failure: (f) => fail(f.code));
    final room = await search.firstWhere((r) => r.available);
    final outcome = rooms.join(room, master.roomCode!, displayName: 'Ana');
    final pending = await master.snapshots.firstWhere((s) =>
        s.participants.any((p) => p.state == ParticipantState.pendingApproval));
    await master.approve(pending.participants.single.id);
    expect(await outcome, JoinOutcome.joined);
  }

  MemberRoomState state() => container.read(memberRoomProvider);

  MemberRoomNotifier notifier() {
    container.listen(memberRoomProvider, (_, __) {});
    return container.read(memberRoomProvider.notifier);
  }

  Future<void> until(bool Function() test) async {
    for (var i = 0; i < 250 && !test(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(test(), isTrue);
  }

  test('shows the master and the song of the joined room (ROOM-42)', () async {
    await joinMarina();
    notifier();

    expect(state().inRoom, isTrue);
    expect(state().masterName, 'Marina');
    expect(state().songName, 'Ave Verum');
  });

  test(
      'the master ending the room is noticed once and the room closes '
      '(ROOM-44)', () async {
    await joinMarina();
    notifier();

    await master.endRoom();

    await until(() => state().lost);
    expect(state().inRoom, isFalse);
    expect(container.read(activeRoomProvider), isNull);
  });

  test('"Sair da sala" closes the room and the master sees it (ROOM-43)',
      () async {
    await joinMarina();
    final n = notifier();
    final dropped = master.snapshots.firstWhere((s) =>
        s.participants.any((p) => p.state == ParticipantState.disconnected));

    await n.leave();

    expect(state().inRoom, isFalse);
    expect(state().lost, isFalse);
    expect(container.read(activeRoomProvider), isNull);
    await dropped.timeout(const Duration(seconds: 5));
  });

  test('with no room the screen knows there is none', () {
    notifier();

    expect(state().inRoom, isFalse);
    expect(state().lost, isFalse);
  });
}
