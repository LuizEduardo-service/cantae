import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/data/session/session_wire_message.dart';
import 'package:cantae/domain/session/ids.dart';
import 'package:cantae/domain/session/room_entry_rules.dart';

void main() {
  group('SessionWireMessage encode/decode round-trip', () {
    test('JoinRequestMessage', () {
      const message = JoinRequestMessage(deviceId: 'device-1', code: '1234');
      final decoded =
          SessionWireMessage.decode(message.encode()) as JoinRequestMessage;
      expect(decoded.deviceId, equals('device-1'));
      expect(decoded.code, equals('1234'));
    });

    test('JoinRejectedMessage', () {
      const message = JoinRejectedMessage(reasonCode: 'session.invalid-code');
      final decoded =
          SessionWireMessage.decode(message.encode()) as JoinRejectedMessage;
      expect(decoded.reasonCode, equals('session.invalid-code'));
    });

    test('HandshakeInitMessage', () {
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final message = HandshakeInitMessage(publicKey: key);
      final decoded =
          SessionWireMessage.decode(message.encode()) as HandshakeInitMessage;
      expect(decoded.publicKey, equals(key));
    });

    test('HandshakeResponseMessage', () {
      final key = Uint8List.fromList(List.generate(32, (i) => i + 1));
      final message = HandshakeResponseMessage(publicKey: key);
      final decoded = SessionWireMessage.decode(message.encode())
          as HandshakeResponseMessage;
      expect(decoded.publicKey, equals(key));
    });

    test(
        'EnvelopeMessage carries requiresMasterRole, sender, sequence, hmac, and payload',
        () {
      final hmac = Uint8List.fromList(List.generate(32, (i) => i));
      final payload = Uint8List.fromList([9, 9, 9]);
      final message = EnvelopeMessage(
        requiresMasterRole: true,
        senderId: const ParticipantId('device-1'),
        sequence: 42,
        hmac: hmac,
        payload: payload,
      );

      final decoded =
          SessionWireMessage.decode(message.encode()) as EnvelopeMessage;

      expect(decoded.requiresMasterRole, isTrue);
      expect(decoded.senderId, equals(const ParticipantId('device-1')));
      expect(decoded.sequence, equals(42));
      expect(decoded.hmac, equals(hmac));
      expect(decoded.payload, equals(payload));
    });

    test('EnvelopeMessage with requiresMasterRole false round-trips correctly',
        () {
      final message = EnvelopeMessage(
        requiresMasterRole: false,
        senderId: const ParticipantId('device-2'),
        sequence: 0,
        hmac: Uint8List(32),
        payload: Uint8List(0),
      );

      final decoded =
          SessionWireMessage.decode(message.encode()) as EnvelopeMessage;

      expect(decoded.requiresMasterRole, isFalse);
      expect(decoded.payload, isEmpty);
    });
  });

  // Failure modes (ROOM-11, ROOM-34): the name or the version is lost on
  // the wire; accents arrive broken; an older app's request (no version)
  // decodes as the current version and gets in.
  group('JoinRequestMessage v2', () {
    JoinRequestMessage roundTrip(JoinRequestMessage m) =>
        SessionWireMessage.decode(m.encode()) as JoinRequestMessage;

    test('carries the protocol version and the name, with accents', () {
      final decoded = roundTrip(const JoinRequestMessage(
        deviceId: 'device-1',
        code: '4827',
        protocolVersion: 7,
        displayName: 'João Conceição',
      ));

      expect(decoded.deviceId, 'device-1');
      expect(decoded.code, '4827');
      expect(decoded.protocolVersion, 7);
      expect(decoded.displayName, 'João Conceição');
    });

    test('defaults to this app version and an empty name', () {
      final decoded = roundTrip(
        const JoinRequestMessage(deviceId: 'd', code: '1111'),
      );

      expect(decoded.protocolVersion, roomProtocolVersion);
      expect(decoded.displayName, '');
    });

    test('a request in the old format decodes as version 0, no name', () {
      final legacy = Uint8List.fromList([
        0x01,
        0, 1, 0x64, // "d"
        0, 4, 0x34, 0x38, 0x32, 0x37, // "4827"
      ]);

      final decoded = SessionWireMessage.decode(legacy) as JoinRequestMessage;

      expect(decoded.deviceId, 'd');
      expect(decoded.code, '4827');
      expect(decoded.protocolVersion, 0);
      expect(decoded.displayName, '');
    });
  });
}
