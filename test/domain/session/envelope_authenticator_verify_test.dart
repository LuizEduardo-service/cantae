import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/session/envelope.dart';
import 'package:cantae/domain/session/envelope_authenticator.dart';
import 'package:cantae/domain/session/ids.dart';

void main() {
  final authenticator = EnvelopeAuthenticator();
  const sender = ParticipantId('participant-1');
  final key = Uint8List.fromList(List.generate(32, (i) => i));
  final otherKey = Uint8List.fromList(List.generate(32, (i) => i + 1));

  Envelope signedEnvelope(
      int sequence, Uint8List payload, Uint8List signingKey) {
    return authenticator.sign(sender, sequence, payload, signingKey);
  }

  group('EnvelopeAuthenticator.verify', () {
    test(
        'tampered payload with stale-but-correct HMAC is rejected as hmac-mismatch (NET-11)',
        () {
      final original =
          signedEnvelope(1, Uint8List.fromList(utf8.encode('hi')), key);
      final tampered = Envelope(
        senderId: original.senderId,
        sequence: original.sequence,
        payload: Uint8List.fromList(utf8.encode('hacked')),
        hmac: original.hmac,
      );

      final result = authenticator.verify(tampered, key, 0);

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) {
          expect(f, isA<NetworkFailure>());
          expect(f.code, equals('session.hmac-mismatch'));
        },
      );
    });

    test('wrong key is rejected as hmac-mismatch (NET-11)', () {
      final envelope =
          signedEnvelope(1, Uint8List.fromList(utf8.encode('hi')), key);

      final result = authenticator.verify(envelope, otherKey, 0);

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) => expect(f.code, equals('session.hmac-mismatch')),
      );
    });

    test(
        'replayed sequence (less than last accepted) is rejected as replay-detected (NET-12)',
        () {
      final envelope =
          signedEnvelope(3, Uint8List.fromList(utf8.encode('hi')), key);

      final result = authenticator.verify(envelope, key, 5);

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) => expect(f.code, equals('session.replay-detected')),
      );
    });

    test(
        'sequence exactly equal to last accepted is rejected as replay-detected (boundary, NET-12)',
        () {
      final envelope =
          signedEnvelope(5, Uint8List.fromList(utf8.encode('hi')), key);

      final result = authenticator.verify(envelope, key, 5);

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) => expect(f.code, equals('session.replay-detected')),
      );
    });

    test('out-of-order-but-valid forward sequence gap is accepted (NET-13)',
        () {
      final envelope =
          signedEnvelope(10001, Uint8List.fromList(utf8.encode('hi')), key);

      final result = authenticator.verify(envelope, key, 1);

      expect(result.isSuccess, isTrue);
    });

    test('valid HMAC with strictly-increasing sequence is accepted (NET-14)',
        () {
      final envelope =
          signedEnvelope(6, Uint8List.fromList(utf8.encode('hi')), key);

      final result = authenticator.verify(envelope, key, 5);

      expect(result.isSuccess, isTrue);
    });
  });
}
