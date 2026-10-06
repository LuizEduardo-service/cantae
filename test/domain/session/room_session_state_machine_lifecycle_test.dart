import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
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

  RoomSessionStateMachine connectedMachine(String deviceId) {
    final machine = newMachine();
    machine.requestJoin(DeviceId(deviceId), '1234', now);
    machine.approve(ParticipantId(deviceId), now);
    machine.completeHandshake(ParticipantId(deviceId), key);
    return machine;
  }

  group('RoomSessionStateMachine.disconnect', () {
    test('unknown participant id fails with session.participant-not-found', () {
      final machine = newMachine();

      final result = machine.disconnect(const ParticipantId('ghost'));

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) => expect(f.code, equals('session.participant-not-found')),
      );
    });

    test(
        'a connected participant is transitioned to disconnected with its session key invalidated (NET-17)',
        () {
      final machine = connectedMachine('device-1');

      final result = machine.disconnect(const ParticipantId('device-1'));

      expect(result.isSuccess, isTrue);
      final session = machine.participant(const ParticipantId('device-1'));
      expect(session!.state, equals(ParticipantState.disconnected));
      expect(session.sessionKey, isNull);
    });

    test(
        'an old session key no longer authenticates envelopes after disconnect (NET-17)',
        () {
      final machine = connectedMachine('device-1');
      machine.disconnect(const ParticipantId('device-1'));

      final envelope = authenticator.sign(
        const ParticipantId('device-1'),
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
  });

  group(
      'rejoin after disconnect (NET-18 edge case: never resume the old session key)',
      () {
    test(
        'a rejoin after disconnect is a brand-new pendingApproval request with no session key',
        () {
      final machine = connectedMachine('device-1');
      machine.disconnect(const ParticipantId('device-1'));

      final rejoinResult = machine.requestJoin(
        const DeviceId('device-1'),
        '1234',
        now,
      );

      expect(rejoinResult.isSuccess, isTrue);
      final session = machine.participant(const ParticipantId('device-1'));
      expect(session!.state, equals(ParticipantState.pendingApproval));
      expect(session.sessionKey, isNull);
    });
  });

  group('RoomSessionStateMachine.tick — connected inactivity TTL (NET-16)', () {
    test(
        'a connected participant silent for more than 30 minutes expires and frees its slot',
        () {
      final machine = connectedMachine('device-1');

      machine.tick(now.add(const Duration(minutes: 31)));

      final session = machine.participant(const ParticipantId('device-1'));
      expect(session!.state, equals(ParticipantState.expired));
    });

    test(
        'a connected participant silent for exactly 30 minutes is not yet expired',
        () {
      final machine = connectedMachine('device-1');

      machine.tick(now.add(const Duration(minutes: 30)));

      final session = machine.participant(const ParticipantId('device-1'));
      expect(session!.state, equals(ParticipantState.connected));
    });

    test(
        'expiry frees the slot so a new join succeeds once the room was previously full (NET-19)',
        () {
      final machine = newMachine();
      for (var i = 0; i < 8; i++) {
        final deviceId = DeviceId('device-$i');
        machine.requestJoin(deviceId, '1234', now);
        machine.approve(ParticipantId('device-$i'), now);
        machine.completeHandshake(ParticipantId('device-$i'), key);
      }

      machine.tick(now.add(const Duration(minutes: 31)));
      final afterExpiry = machine.requestJoin(
        const DeviceId('device-9'),
        '1234',
        now.add(const Duration(minutes: 31)),
      );

      expect(afterExpiry.isSuccess, isTrue);
    });
  });

  group('RoomSessionStateMachine.endRoom (NET-20)', () {
    test(
        'disconnects every participant regardless of prior state and ends the room',
        () {
      final machine = newMachine();
      machine.requestJoin(const DeviceId('pending-device'), '1234', now);
      machine.requestJoin(const DeviceId('approved-device'), '1234', now);
      machine.approve(const ParticipantId('approved-device'), now);
      machine.requestJoin(const DeviceId('connected-device'), '1234', now);
      machine.approve(const ParticipantId('connected-device'), now);
      machine.completeHandshake(const ParticipantId('connected-device'), key);

      machine.endRoom();

      for (final id in [
        'pending-device',
        'approved-device',
        'connected-device'
      ]) {
        final session = machine.participant(ParticipantId(id));
        expect(session!.state, equals(ParticipantState.disconnected));
        expect(session.sessionKey, isNull);
      }
      expect(machine.room.state, equals(RoomLifecycle.ended));
    });
  });
}
