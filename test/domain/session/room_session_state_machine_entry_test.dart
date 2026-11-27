import 'dart:typed_data';

import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/session/ids.dart';
import 'package:cantae/domain/session/participant_session.dart';
import 'package:cantae/domain/session/room.dart';
import 'package:cantae/domain/session/room_entry_rules.dart';
import 'package:cantae/domain/session/room_session_state_machine.dart';
import 'package:flutter_test/flutter_test.dart';

// Failure modes (ROOM-11, ROOM-34, ROOM-46):
// - an app on another protocol version gets "invalid code" (wrong banner)
//   instead of "incompatible version";
// - a request without a version (older app) is admitted;
// - the name typed by the singer is lost before the master sees it, or
//   after the approval;
// - a request with the right code reaches the room without "Aprovar".
void main() {
  const marina = DeviceId('marina');
  final now = DateTime(2026, 11, 26, 19);

  RoomSessionStateMachine newMachine() => RoomSessionStateMachine(
        room: const Room(
          id: RoomId('room-1'),
          code: '4827',
          masterId: DeviceId('master'),
          state: RoomLifecycle.advertising,
        ),
      );

  String? failureCode(RoomSessionStateMachine m, String code, int version) => m
      .requestJoin(marina, code, now,
          displayName: 'Marina', protocolVersion: version)
      .when(success: (_) => null, failure: (f) => f.code);

  test(
      'another protocol version is refused as a mismatch, even with the '
      'right code (ROOM-34)', () {
    final machine = newMachine();

    expect(failureCode(machine, '4827', roomProtocolVersion + 1),
        'session.protocol-mismatch');
    expect(machine.participant(const ParticipantId('marina')), isNull);
  });

  test('the mismatch is reported before a wrong code', () {
    expect(failureCode(newMachine(), '0000', roomProtocolVersion + 1),
        'session.protocol-mismatch');
  });

  test('a request without a version (0) is refused as a mismatch', () {
    expect(failureCode(newMachine(), '4827', 0), 'session.protocol-mismatch');
  });

  test('the name is kept on the pending request and after approval (ROOM-11)',
      () {
    final machine = newMachine();
    expect(failureCode(machine, '4827', roomProtocolVersion), isNull);
    const id = ParticipantId('marina');

    expect(machine.participant(id)!.displayName, 'Marina');
    machine.approve(id, now);
    expect(machine.participant(id)!.displayName, 'Marina');
    machine.completeHandshake(id, Uint8List(32));
    expect(machine.participant(id)!.state, ParticipantState.connected);
    expect(machine.participant(id)!.displayName, 'Marina');
  });

  test('a pending request never becomes connected without approve (ROOM-46)',
      () {
    final machine = newMachine();
    failureCode(machine, '4827', roomProtocolVersion);
    const id = ParticipantId('marina');

    final result = machine.completeHandshake(id, Uint8List(32));

    expect(
      result.when(success: (_) => null, failure: (Failure f) => f.code),
      'session.participant-not-approved',
    );
    expect(machine.participant(id)!.state, ParticipantState.pendingApproval);
  });
}
