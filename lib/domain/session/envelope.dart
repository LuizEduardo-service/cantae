import 'dart:typed_data';

import 'ids.dart';

class Envelope {
  final ParticipantId senderId;
  final int sequence;
  final Uint8List payload;
  final Uint8List hmac;

  const Envelope({
    required this.senderId,
    required this.sequence,
    required this.payload,
    required this.hmac,
  });
}
