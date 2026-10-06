import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/domain/session/handshake_service.dart';

class _WrongLengthHkdf extends Hkdf {
  const _WrongLengthHkdf() : super.constructor();

  @override
  Hmac get hmac => Hmac.sha256();

  @override
  int get outputLength => 32;

  @override
  Future<SecretKeyData> deriveKey({
    required SecretKey secretKey,
    List<int> nonce = const <int>[],
    List<int> info = const <int>[],
  }) async {
    return SecretKeyData(Uint8List(16));
  }
}

void main() {
  group('HandshakeService', () {
    test(
        'two independently generated keypairs derive matching 32-byte session keys',
        () async {
      final service = HandshakeService();

      final alice = await service.generateEphemeralKeyPair();
      final bob = await service.generateEphemeralKeyPair();

      final aliceKey = await service.deriveSessionKey(
        alice,
        bob.publicKeyBytes,
      );
      final bobKey = await service.deriveSessionKey(
        bob,
        alice.publicKeyBytes,
      );

      expect(aliceKey.isSuccess, isTrue);
      expect(bobKey.isSuccess, isTrue);

      aliceKey.when(
        success: (aliceBytes) {
          expect(aliceBytes.length, equals(32));
          bobKey.when(
            success: (bobBytes) => expect(bobBytes, equals(aliceBytes)),
            failure: (_) => fail('expected success'),
          );
        },
        failure: (_) => fail('expected success'),
      );
    });

    test(
        'malformed/wrong-length peer public key fails with session.handshake-failed',
        () async {
      final service = HandshakeService();
      final self = await service.generateEphemeralKeyPair();
      final malformedPeerKey = Uint8List.fromList([1, 2, 3]);

      final result = await service.deriveSessionKey(self, malformedPeerKey);

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) => expect(f.code, equals('session.handshake-failed')),
      );
    });

    test(
        'a derived key of unexpected length fails with session.handshake-failed instead of truncating/padding',
        () async {
      final service = HandshakeService(kdf: const _WrongLengthHkdf());
      final alice = await service.generateEphemeralKeyPair();
      final bob = await service.generateEphemeralKeyPair();

      final result = await service.deriveSessionKey(alice, bob.publicKeyBytes);

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) => expect(f.code, equals('session.handshake-failed')),
      );
    });
  });
}
