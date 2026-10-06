import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/data/session/session_wire_message.dart';
import 'package:cantae/domain/session/ids.dart';

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
}
