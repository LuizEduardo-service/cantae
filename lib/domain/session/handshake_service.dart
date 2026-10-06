import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../core/failures.dart';
import '../core/result.dart';

const _sessionKeyLength = 32;

class EphemeralKeyPair {
  final SimpleKeyPair keyPair;
  final Uint8List publicKeyBytes;

  const EphemeralKeyPair({required this.keyPair, required this.publicKeyBytes});
}

/// Ephemeral X25519 ECDH handshake + HKDF-SHA256 session-key derivation.
///
/// SPEC_DEVIATION: design.md declares `generateEphemeralKeyPair()` as a
/// synchronous method, but the `cryptography` package's `X25519.newKeyPair()`
/// is async-only (it has no synchronous key-generation path for a
/// secure-random seed). Both methods here are async to match the real API.
class HandshakeService {
  final X25519 _algorithm;
  final Hkdf _kdf;

  HandshakeService({X25519? algorithm, Hkdf? kdf})
      : _algorithm = algorithm ?? X25519(),
        _kdf =
            kdf ?? Hkdf(hmac: Hmac.sha256(), outputLength: _sessionKeyLength);

  Future<EphemeralKeyPair> generateEphemeralKeyPair() async {
    final keyPair = await _algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    return EphemeralKeyPair(
      keyPair: keyPair,
      publicKeyBytes: Uint8List.fromList(publicKey.bytes),
    );
  }

  Future<Result<Uint8List, Failure>> deriveSessionKey(
    EphemeralKeyPair self,
    Uint8List peerPublicKey,
  ) async {
    try {
      final remotePublicKey = SimplePublicKey(
        peerPublicKey,
        type: KeyPairType.x25519,
      );
      final sharedSecret = await _algorithm.sharedSecretKey(
        keyPair: self.keyPair,
        remotePublicKey: remotePublicKey,
      );
      final derived = await _kdf.deriveKey(secretKey: sharedSecret);
      final bytes = Uint8List.fromList(await derived.extractBytes());

      if (bytes.length != _sessionKeyLength) {
        return Result.failure(NetworkFailure(code: 'session.handshake-failed'));
      }
      return Result.success(bytes);
    } catch (_) {
      return Result.failure(NetworkFailure(code: 'session.handshake-failed'));
    }
  }
}
