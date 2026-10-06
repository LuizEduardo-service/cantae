import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../core/constant_time_equals.dart';
import '../core/failures.dart';
import '../core/result.dart';
import '../core/unit.dart';
import 'envelope.dart';
import 'ids.dart';

class EnvelopeAuthenticator {
  Envelope sign(
    ParticipantId sender,
    int sequence,
    Uint8List payload,
    Uint8List key,
  ) {
    final digest = Hmac(
      sha256,
      key,
    ).convert(_signedBytes(sender, sequence, payload));
    return Envelope(
      senderId: sender,
      sequence: sequence,
      payload: payload,
      hmac: Uint8List.fromList(digest.bytes),
    );
  }

  Result<Unit, Failure> verify(
    Envelope envelope,
    Uint8List key,
    int lastAcceptedSequence,
  ) {
    final expectedHmac = Hmac(sha256, key).convert(
      _signedBytes(envelope.senderId, envelope.sequence, envelope.payload),
    );
    if (!constantTimeEquals(expectedHmac.bytes, envelope.hmac)) {
      return Result.failure(NetworkFailure(code: 'session.hmac-mismatch'));
    }

    if (envelope.sequence <= lastAcceptedSequence) {
      return Result.failure(NetworkFailure(code: 'session.replay-detected'));
    }

    return const Result.success(Unit());
  }

  Uint8List _signedBytes(
    ParticipantId sender,
    int sequence,
    Uint8List payload,
  ) {
    final senderBytes = utf8.encode(sender.value);
    final sequenceBytes = Uint8List(8)
      ..buffer.asByteData().setInt64(0, sequence);
    return Uint8List.fromList([
      ...senderBytes,
      ...sequenceBytes,
      ...payload,
    ]);
  }
}
