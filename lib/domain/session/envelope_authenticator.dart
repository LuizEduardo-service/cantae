import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

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
