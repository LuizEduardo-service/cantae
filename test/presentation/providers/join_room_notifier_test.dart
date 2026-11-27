import 'dart:async';

import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/session/ids.dart';
import 'package:cantae/domain/session/room_discovery.dart';
import 'package:cantae/domain/session/room_entry_rules.dart';
import 'package:cantae/domain/session/system_settings.dart';
import 'package:cantae/presentation/providers/active_room_notifier.dart';
import 'package:cantae/presentation/providers/join_room_notifier.dart';
import 'package:cantae/presentation/providers/room_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/room_fakes.dart';

// Failure modes (ROOM-22..37, 55, 56, 58):
// - "Nenhuma sala" shows while rooms are on the list, or never shows;
//   a room found after it does not appear; "Procurar de novo" does not
//   search again;
// - the same room twice makes two tiles; a room that left stays;
// - letters or a 5th digit get into the code; "Entrar" works with 3;
// - a chosen room is ignored and the code goes to every room;
// - without a choice, a "wrong code" answer stops the search instead of
//   asking the next room, or two rooms both get the request;
// - every room refusing the code is not shown as "Código não encontrado",
//   or "Digitar de novo" keeps the old code;
// - a second "Entrar" while waiting sends a second request;
// - a refusal, a full room, another version, no answer or a lost
//   connection end in the wrong banner;
// - "Cancelar pedido" leaves the screen waiting;
// - a denied permission looks like "Nenhuma sala".
const _marina = DiscoveredRoom(
  id: RoomId('marina'),
  host: '10.0.0.2',
  port: 1,
  masterName: 'Marina',
  songName: 'Ave Verum Corpus',
);
const _bruno = DiscoveredRoom(
    id: RoomId('bruno'), host: '10.0.0.3', port: 1, masterName: 'Bruno');

/// Rooms and answers the test controls.
class _ScriptedRooms extends ActiveRoomNotifier {
  _ScriptedRooms()
      : super(
          newController: (_) => throw UnimplementedError(),
          profiles: InMemoryLocalProfiles('ana'),
        );

  var wifi = StreamController<DiscoveredRoom>.broadcast();
  var searches = 0;
  var closes = 0;
  var cancels = 0;
  final asked = <(RoomId, String, String)>[];

  /// Answer per room; a room missing here never answers until cancelled.
  final answers = <RoomId, JoinOutcome>{};
  Completer<JoinOutcome>? _waiting;

  @override
  Future<Result<Stream<DiscoveredRoom>, Failure>> search() async {
    searches++;
    wifi = StreamController<DiscoveredRoom>.broadcast();
    return Result.success(wifi.stream);
  }

  @override
  Future<JoinOutcome> join(
    DiscoveredRoom room,
    String code, {
    required String displayName,
  }) {
    asked.add((room.id, code, displayName));
    final answer = answers[room.id];
    if (answer != null) return Future.value(answer);
    return (_waiting = Completer<JoinOutcome>()).future;
  }

  @override
  Future<void> cancelJoin() async {
    cancels++;
    _waiting?.complete(JoinOutcome.cancelled);
  }

  @override
  Future<void> close() async => closes++;
}

class _Settings implements SystemSettings {
  var opened = 0;

  @override
  Future<void> openAppSettings() async => opened++;
}

void main() {
  late _ScriptedRooms rooms;
  late _Settings settings;
  late ProviderContainer container;

  setUp(() {
    rooms = _ScriptedRooms();
    settings = _Settings();
    container = ProviderContainer(overrides: [
      activeRoomProvider.overrideWith((ref) => rooms),
      systemSettingsProvider.overrideWithValue(settings),
      joinSearchTimeoutProvider
          .overrideWithValue(const Duration(milliseconds: 100)),
    ]);
  });
  tearDown(() => container.dispose());

  JoinRoomNotifier notifier() {
    container.listen(joinRoomProvider, (_, __) {});
    return container.read(joinRoomProvider.notifier);
  }

  JoinRoomState state() => container.read(joinRoomProvider);

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<JoinRoomNotifier> started(
      {List<DiscoveredRoom> found = const []}) async {
    final n = notifier();
    await n.start(displayName: 'Ana');
    for (final room in found) {
      rooms.wifi.add(room);
    }
    await settle();
    return n;
  }

  test('starts searching with an empty list (ROOM-22)', () async {
    await started();

    expect(state().phase, JoinPhase.searching);
    expect(state().rooms, isEmpty);
    expect(rooms.searches, 1);
  });

  test('a found room is listed with master and song, no code (ROOM-23)',
      () async {
    await started(found: [_marina]);

    final tile = state().rooms.single;
    expect(tile.masterName, 'Marina');
    expect(tile.songName, 'Ave Verum Corpus');
  });

  test(
      'nothing found in the timeout shows "Nenhuma sala"; a later room '
      'still appears (ROOM-24)', () async {
    await started();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(state().phase, JoinPhase.noneFound);

    rooms.wifi.add(_marina);
    await settle();

    expect(state().rooms.single.masterName, 'Marina');
    expect(state().phase, JoinPhase.searching);
  });

  test('a room found before the timeout prevents "Nenhuma sala"', () async {
    await started(found: [_marina]);
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(state().phase, JoinPhase.searching);
  });

  test('"Procurar de novo" searches again', () async {
    final n = await started();
    await Future<void>.delayed(const Duration(milliseconds: 150));

    await n.searchAgain();

    expect(rooms.searches, 2);
    expect(state().phase, JoinPhase.searching);
  });

  test(
      'the same room twice is one tile; a room that left is removed '
      '(ROOM-56)', () async {
    await started(found: [_marina, _marina, _bruno]);
    expect(state().rooms.map((r) => r.masterName), ['Marina', 'Bruno']);

    rooms.wifi.add(const DiscoveredRoom(
        id: RoomId('marina'), host: '', port: 0, available: false));
    await settle();

    expect(state().rooms.map((r) => r.masterName), ['Bruno']);
  });

  test('the code keeps digits only, at most 4; "Entrar" needs 4 (ROOM-27)',
      () async {
    final n = await started(found: [_marina]);

    n.setCode('4a8 2');
    expect(state().code, '482');
    expect(state().canSubmit, isFalse);
    await n.submitCode();
    expect(rooms.asked, isEmpty);

    n.setCode('482791');
    expect(state().code, '4827');
    expect(state().canSubmit, isTrue);
  });

  test('a chosen room gets the code, and only it (ROOM-28)', () async {
    final n = await started(found: [_marina, _bruno]);
    rooms.answers[_bruno.id] = JoinOutcome.joined;

    n.selectRoom(_bruno.id);
    n.setCode('4827');
    await n.submitCode();

    expect(rooms.asked, [(_bruno.id, '4827', 'Ana')]);
    expect(state().outcome, JoinOutcome.joined);
  });

  test(
      'without a choice, rooms are asked in order and the first that takes '
      'the code keeps the request (ROOM-25, ROOM-58)', () async {
    final n = await started(found: [_marina, _bruno]);
    rooms.answers[_marina.id] = JoinOutcome.invalidCode;
    rooms.answers[_bruno.id] = JoinOutcome.joined;

    n.setCode('4827');
    await n.submitCode();

    expect(rooms.asked.map((a) => a.$1), [_marina.id, _bruno.id]);
    expect(state().phase, JoinPhase.outcome);
    expect(state().outcome, JoinOutcome.joined);
    expect(state().target!.masterName, 'Bruno');
  });

  test(
      'the first room that takes the code stops the search, even if a '
      'later one has it too (ROOM-58)', () async {
    final n = await started(found: [_marina, _bruno]);
    n.setCode('4827');

    final submitting = n.submitCode();
    await settle();

    expect(state().phase, JoinPhase.awaiting);
    expect(state().target!.masterName, 'Marina');
    expect(rooms.asked.map((a) => a.$1), [_marina.id]);
    await n.cancelRequest();
    await submitting;
  });

  test(
      'no room takes the code → "Código não encontrado"; "Digitar de novo" '
      'clears it (ROOM-26)', () async {
    final n = await started(found: [_marina, _bruno]);
    rooms.answers[_marina.id] = JoinOutcome.invalidCode;
    rooms.answers[_bruno.id] = JoinOutcome.invalidCode;
    n.setCode('1111');

    await n.submitCode();
    expect(state().phase, JoinPhase.codeNotFound);

    n.dismissOutcome();
    expect(state().code, '');
    expect(state().phase, JoinPhase.searching);
  });

  test('a code with no room found → "Código não encontrado"', () async {
    final n = await started();
    n.setCode('1111');

    await n.submitCode();

    expect(state().phase, JoinPhase.codeNotFound);
  });

  test('the chosen room refusing the code → "Código não encontrado"', () async {
    final n = await started(found: [_marina, _bruno]);
    rooms.answers[_marina.id] = JoinOutcome.invalidCode;
    n.selectRoom(_marina.id);
    n.setCode('1111');

    await n.submitCode();

    expect(state().phase, JoinPhase.codeNotFound);
    expect(rooms.asked.map((a) => a.$1), [_marina.id]);
  });

  test(
      'while waiting, taps and a second "Entrar" do nothing (ROOM-29, '
      'ROOM-55)', () async {
    final n = await started(found: [_marina, _bruno]);
    n.selectRoom(_marina.id);
    n.setCode('4827');
    final submitting = n.submitCode();
    await settle();
    expect(state().phase, JoinPhase.awaiting);

    await n.submitCode();
    n.selectRoom(_bruno.id);
    n.setCode('1111');

    expect(rooms.asked, hasLength(1));
    expect(state().selected, _marina.id);
    expect(state().code, '4827');
    await n.cancelRequest();
    await submitting;
  });

  test('"Cancelar pedido" goes back to the list (ROOM-30)', () async {
    final n = await started(found: [_marina]);
    n.setCode('4827');
    final submitting = n.submitCode();
    await settle();

    await n.cancelRequest();
    await submitting;

    expect(rooms.cancels, 1);
    expect(state().phase, JoinPhase.searching);
    expect(state().target, isNull);
  });

  for (final outcome in [
    JoinOutcome.rejected,
    JoinOutcome.roomFull,
    JoinOutcome.protocolMismatch,
    JoinOutcome.expired,
    JoinOutcome.connectionLost,
  ]) {
    test('${outcome.name} ends in its own outcome (ROOM-32..36)', () async {
      final n = await started(found: [_marina]);
      rooms.answers[_marina.id] = outcome;
      n.setCode('4827');

      await n.submitCode();

      expect(state().phase, JoinPhase.outcome);
      expect(state().outcome, outcome);
      expect(state().target!.id, _marina.id);
    });
  }

  test('"Escolher outra sala" goes back to the list (ROOM-32, ROOM-33)',
      () async {
    final n = await started(found: [_marina]);
    rooms.answers[_marina.id] = JoinOutcome.rejected;
    n.setCode('4827');
    await n.submitCode();

    n.dismissOutcome();

    expect(state().phase, JoinPhase.searching);
    expect(state().outcome, isNull);
  });

  test('"Tentar de novo" asks the same room again (ROOM-35, ROOM-36)',
      () async {
    final n = await started(found: [_marina, _bruno]);
    rooms.answers[_bruno.id] = JoinOutcome.expired;
    n.selectRoom(_bruno.id);
    n.setCode('4827');
    await n.submitCode();
    rooms.answers[_bruno.id] = JoinOutcome.joined;

    await n.retry();

    expect(rooms.asked.map((a) => a.$1), [_bruno.id, _bruno.id]);
    expect(state().outcome, JoinOutcome.joined);
  });

  test(
      'a denied permission has its own state and opens the settings '
      '(ROOM-37)', () async {
    final n = await started();

    rooms.wifi.addError(NetworkFailure(code: 'discovery.permission-denied'));
    await settle();
    await n.openSettings();

    expect(state().phase, JoinPhase.permissionDenied);
    expect(settings.opened, 1);
  });

  test('another discovery error shows "Nenhuma sala"', () async {
    await started();

    rooms.wifi.addError(NetworkFailure(code: 'discovery.failed'));
    await settle();

    expect(state().phase, JoinPhase.noneFound);
  });

  test('leaving the screen without joining stops the search', () async {
    await started(found: [_marina]);

    container.invalidate(joinRoomProvider);
    await settle();

    expect(rooms.closes, 1);
  });

  test('leaving the screen after joining keeps the room', () async {
    final n = await started(found: [_marina]);
    rooms.answers[_marina.id] = JoinOutcome.joined;
    n.setCode('4827');
    await n.submitCode();

    container.invalidate(joinRoomProvider);
    await settle();

    expect(rooms.closes, 0);
  });
}
