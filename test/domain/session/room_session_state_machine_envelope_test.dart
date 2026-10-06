import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/session/envelope_authenticator.dart';
import 'package:cantae/domain/session/ids.dart';
import 'package:cantae/domain/session/participant_session.dart';
import 'package:cantae/domain/session/room.dart';
import 'package:cantae/domain/session/room_session_state_machine.dart';

void main() {
  const masterId = DeviceId('master-device');
  const roomId = RoomId('room-1');
  final now = DateTime(2026, 1, 1, 12);
  final authenticator = EnvelopeAuthenticator();
  final key = Uint8List.fromList(List.generate(32, (i) => i));
  final otherKey = Uint8List.fromList(List.generate(32, (i) => i + 1));

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

  group('RoomSessionStateMachine.completeHandshake', () {
    test(
        'transitions an approved participant to connected with the session key set',
        () {
      final machine = newMachine();
      machine.requestJoin(const DeviceId('device-1'), '1234', now);
      machine.approve(const ParticipantId('device-1'), now);

      final result = machine.completeHandshake(
        const ParticipantId('device-1'),
        key,
      );

      expect(result.isSuccess, isTrue);
      final session = machine.participant(const ParticipantId('device-1'));
      expect(session!.state, equals(ParticipantState.connected));
      expect(session.sessionKey, equals(key));
    });

    test('unknown participant id fails with session.participant-not-found', () {
      final machine = newMachine();

      final result =
          machine.completeHandshake(const ParticipantId('ghost'), key);

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) => expect(f.code, equals('session.participant-not-found')),
      );
    });

    test(
        'participant not in approved state fails with session.participant-not-approved',
        () {
      final machine = newMachine();
      machine.requestJoin(const DeviceId('device-1'), '1234', now);

      final result = machine.completeHandshake(
        const ParticipantId('device-1'),
        key,
      );

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) =>
            expect(f.code, equals('session.participant-not-approved')),
      );
    });
  });

  group('RoomSessionStateMachine.acceptEnvelope', () {
    RoomSessionStateMachine connectedMachine(String deviceId) {
      final machine = newMachine();
      machine.requestJoin(DeviceId(deviceId), '1234', now);
      machine.approve(ParticipantId(deviceId), now);
      machine.completeHandshake(ParticipantId(deviceId), key);
      return machine;
    }

    test(
        'valid HMAC with strictly-increasing sequence is accepted and advances lastAcceptedSequence (NET-10/NET-14)',
        () {
      final machine = connectedMachine('device-1');
      final envelope = authenticator.sign(
        const ParticipantId('device-1'),
        1,
        Uint8List.fromList(utf8.encode('hi')),
        key,
      );

      final result = machine.acceptEnvelope(envelope, now);

      expect(result.isSuccess, isTrue);
      final session = machine.participant(const ParticipantId('device-1'));
      expect(session!.lastAcceptedSequence, equals(1));
    });

    test('envelope from an unknown sender is rejected and state is unchanged',
        () {
      final machine = connectedMachine('device-1');
      final envelope = authenticator.sign(
        const ParticipantId('ghost'),
        1,
        Uint8List.fromList(utf8.encode('hi')),
        key,
      );

      final result = machine.acceptEnvelope(envelope, now);

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) => expect(f.code, equals('session.participant-not-found')),
      );
    });

    test(
        'envelope from a sender that has not completed handshake (approved, not connected) is rejected like unknown',
        () {
      final machine = newMachine();
      machine.requestJoin(const DeviceId('device-2'), '1234', now);
      machine.approve(const ParticipantId('device-2'), now);
      final envelope = authenticator.sign(
        const ParticipantId('device-2'),
        1,
        Uint8List.fromList(utf8.encode('hi')),
        key,
      );

      final result = machine.acceptEnvelope(envelope, now);

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) => expect(f.code, equals('session.participant-not-found')),
      );
    });

    test(
        'tampered HMAC is rejected via EnvelopeAuthenticator and lastAcceptedSequence is unchanged (NET-11)',
        () {
      final machine = connectedMachine('device-1');
      final tamperedEnvelope = authenticator.sign(
        const ParticipantId('device-1'),
        1,
        Uint8List.fromList(utf8.encode('payload')),
        otherKey, // signed with the wrong key, so HMAC won't match device-1's real key
      );

      final result = machine.acceptEnvelope(tamperedEnvelope, now);

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) => expect(f.code, equals('session.hmac-mismatch')),
      );
      final session = machine.participant(const ParticipantId('device-1'));
      expect(session!.lastAcceptedSequence, equals(-1));
    });

    test(
        'a Visitor sending a Master-only message type is rejected and state is unchanged (NET-15)',
        () {
      final machine = connectedMachine('device-1');
      final envelope = authenticator.sign(
        const ParticipantId('device-1'),
        1,
        Uint8List.fromList(utf8.encode('master-only-command')),
        key,
      );

      final result = machine.acceptEnvelope(
        envelope,
        now,
        requiresMasterRole: true,
      );

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) {
          expect(f, isA<ValidationFailure>());
          expect(f.code, equals('session.unauthorized-role'));
        },
      );
      final session = machine.participant(const ParticipantId('device-1'));
      expect(session!.lastAcceptedSequence, equals(-1));
    });
  });
}
