import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/domain/session/envelope_authenticator.dart';
import 'package:cantae/domain/session/ids.dart';

Uint8List _referenceHmac(
  ParticipantId sender,
  int sequence,
  Uint8List payload,
  Uint8List key,
) {
  final sequenceBytes = Uint8List(8)..buffer.asByteData().setInt64(0, sequence);
  final signed = Uint8List.fromList([
    ...utf8.encode(sender.value),
    ...sequenceBytes,
    ...payload,
  ]);
  return Uint8List.fromList(Hmac(sha256, key).convert(signed).bytes);
}

void main() {
  final authenticator = EnvelopeAuthenticator();
  const sender = ParticipantId('participant-1');
  final key = Uint8List.fromList(List.generate(32, (i) => i));

  group('EnvelopeAuthenticator.sign', () {
    test('happy path produces a 32-byte HMAC matching the reference vector',
        () {
      final payload = Uint8List.fromList(utf8.encode('hello'));
      final envelope = authenticator.sign(sender, 1, payload, key);

      expect(envelope.hmac.length, equals(32));
      expect(envelope.hmac, equals(_referenceHmac(sender, 1, payload, key)));
      expect(envelope.senderId, equals(sender));
      expect(envelope.sequence, equals(1));
      expect(envelope.payload, equals(payload));
    });

    test('empty payload still produces a correct 32-byte HMAC', () {
      final payload = Uint8List(0);
      final envelope = authenticator.sign(sender, 1, payload, key);

      expect(envelope.hmac.length, equals(32));
      expect(envelope.hmac, equals(_referenceHmac(sender, 1, payload, key)));
    });

    test('max-size payload is not truncated and HMAC matches the reference',
        () {
      final payload = Uint8List.fromList(List.generate(65536, (i) => i % 256));
      final envelope = authenticator.sign(sender, 1, payload, key);

      expect(envelope.payload.length, equals(65536));
      expect(envelope.hmac.length, equals(32));
      expect(envelope.hmac, equals(_referenceHmac(sender, 1, payload, key)));
    });

    test(
        'key length mismatch (shorter than block size) still yields a correct 32-byte HMAC',
        () {
      final payload = Uint8List.fromList(utf8.encode('hello'));
      final shortKey = Uint8List.fromList([1, 2, 3, 4]);
      final envelope = authenticator.sign(sender, 1, payload, shortKey);

      expect(envelope.hmac.length, equals(32));
      expect(
          envelope.hmac, equals(_referenceHmac(sender, 1, payload, shortKey)));
    });
  });
}
