import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/session/ids.dart';
import 'package:cantae/domain/session/participant_session.dart';
import 'package:cantae/domain/session/room.dart';
import 'package:cantae/domain/session/room_session_state_machine.dart';

void main() {
  const masterId = DeviceId('master-device');
  const roomId = RoomId('room-1');
  final now = DateTime(2026, 1, 1, 12);

  RoomSessionStateMachine newMachine() {
    return RoomSessionStateMachine(
      room: Room(
        id: roomId,
        code: '1234',
        masterId: masterId,
        state: RoomLifecycle.advertising,
      ),
    );
  }

  group('RoomSessionStateMachine — construction (contributes to NET-01)', () {
    test('a newly constructed room starts in advertising state', () {
      final machine = newMachine();
      expect(machine.room.state, equals(RoomLifecycle.advertising));
    });
  });

  group('RoomSessionStateMachine.requestJoin', () {
    test('valid code transitions the request to pendingApproval (NET-03)', () {
      final machine = newMachine();
      final result = machine.requestJoin(
        const DeviceId('device-1'),
        '1234',
        now,
      );

      expect(result.isSuccess, isTrue);
      final session = machine.participant(const ParticipantId('device-1'));
      expect(session, isNotNull);
      expect(session!.state, equals(ParticipantState.pendingApproval));
    });

    test(
        'wrong code is rejected with session.invalid-code and creates no pending entry (NET-04)',
        () {
      final machine = newMachine();
      final result = machine.requestJoin(
        const DeviceId('device-1'),
        '0000',
        now,
      );

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) {
          expect(f, isA<ValidationFailure>());
          expect(f.code, equals('session.invalid-code'));
        },
      );
      expect(machine.participant(const ParticipantId('device-1')), isNull);
    });

    test(
        'room at 8/8 approved rejects a new request before any handshake step (NET-08)',
        () {
      final machine = newMachine();
      for (var i = 0; i < 8; i++) {
        final deviceId = DeviceId('device-$i');
        machine.requestJoin(deviceId, '1234', now);
        machine.approve(ParticipantId('device-$i'), now);
      }

      final result = machine.requestJoin(
        const DeviceId('device-9'),
        '1234',
        now,
      );

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) => expect(f.code, equals('session.room-full')),
      );
    });
  });

  group('RoomSessionStateMachine.approve', () {
    test('approving a pending request admits the participant', () {
      final machine = newMachine();
      machine.requestJoin(const DeviceId('device-1'), '1234', now);

      final result = machine.approve(const ParticipantId('device-1'), now);

      expect(result.isSuccess, isTrue);
      final session = machine.participant(const ParticipantId('device-1'));
      expect(session!.state, equals(ParticipantState.approved));
    });

    test(
        'approving an unknown participant id fails with session.participant-not-found',
        () {
      final machine = newMachine();

      final result = machine.approve(const ParticipantId('ghost'), now);

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) {
          expect(f, isA<NotFoundFailure>());
          expect(f.code, equals('session.participant-not-found'));
        },
      );
    });

    test(
        'approving an already-approved (non-pendingApproval) participant fails with session.participant-not-pending',
        () {
      final machine = newMachine();
      machine.requestJoin(const DeviceId('device-1'), '1234', now);
      machine.approve(const ParticipantId('device-1'), now);

      final result = machine.approve(const ParticipantId('device-1'), now);

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) =>
            expect(f.code, equals('session.participant-not-pending')),
      );
    });

    test(
        'two pending requests racing for the last of 8 slots: second approval fails with session.room-full',
        () {
      final machine = newMachine();
      for (var i = 0; i < 7; i++) {
        final deviceId = DeviceId('device-$i');
        machine.requestJoin(deviceId, '1234', now);
        machine.approve(ParticipantId('device-$i'), now);
      }

      machine.requestJoin(const DeviceId('racer-a'), '1234', now);
      machine.requestJoin(const DeviceId('racer-b'), '1234', now);

      final firstApproval =
          machine.approve(const ParticipantId('racer-a'), now);
      final secondApproval =
          machine.approve(const ParticipantId('racer-b'), now);

      expect(firstApproval.isSuccess, isTrue);
      expect(secondApproval.isFailure, isTrue);
      secondApproval.when(
        success: (_) => fail('expected failure'),
        failure: (f) => expect(f.code, equals('session.room-full')),
      );
    });
  });

  group('RoomSessionStateMachine.reject', () {
    test('rejecting a pending request transitions it to rejected (NET-06)', () {
      final machine = newMachine();
      machine.requestJoin(const DeviceId('device-1'), '1234', now);

      final result = machine.reject(const ParticipantId('device-1'));

      expect(result.isSuccess, isTrue);
      final session = machine.participant(const ParticipantId('device-1'));
      expect(session!.state, equals(ParticipantState.rejected));
    });

    test(
        'rejecting an unknown participant id fails with session.participant-not-found',
        () {
      final machine = newMachine();

      final result = machine.reject(const ParticipantId('ghost'));

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) => expect(f.code, equals('session.participant-not-found')),
      );
    });
  });

  group('RoomSessionStateMachine.tick', () {
    test(
        'a pendingApproval request older than 60s is expired to rejected (NET-09)',
        () {
      final machine = newMachine();
      machine.requestJoin(const DeviceId('device-1'), '1234', now);

      machine.tick(now.add(const Duration(seconds: 61)));

      final session = machine.participant(const ParticipantId('device-1'));
      expect(session!.state, equals(ParticipantState.rejected));
    });

    test('a pendingApproval request at exactly 60s is not yet expired', () {
      final machine = newMachine();
      machine.requestJoin(const DeviceId('device-1'), '1234', now);

      machine.tick(now.add(const Duration(seconds: 60)));

      final session = machine.participant(const ParticipantId('device-1'));
      expect(session!.state, equals(ParticipantState.pendingApproval));
    });
  });
}
