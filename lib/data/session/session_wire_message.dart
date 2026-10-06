import 'dart:convert';
import 'dart:typed_data';

import 'package:cantae/domain/session/ids.dart';

abstract class SessionWireMessage {
  const SessionWireMessage();

  Uint8List encode();

  static SessionWireMessage decode(Uint8List bytes) {
    final tag = bytes[0];
    final body = Uint8List.sublistView(bytes, 1);
    switch (tag) {
      case 0x01:
        return JoinRequestMessage._decodeBody(body);
      case 0x02:
        return JoinRejectedMessage._decodeBody(body);
      case 0x03:
        return HandshakeInitMessage._decodeBody(body);
      case 0x04:
        return HandshakeResponseMessage._decodeBody(body);
      case 0x05:
        return EnvelopeMessage._decodeBody(body);
      default:
        throw ArgumentError('Unknown session wire message tag: $tag');
    }
  }
}

Uint8List _withU16LenString(int tag, String value, [Uint8List? tail]) {
  final valueBytes = utf8.encode(value);
  final out = BytesBuilder();
  out.addByte(tag);
  final lenBytes = ByteData(2)..setUint16(0, valueBytes.length);
  out.add(lenBytes.buffer.asUint8List());
  out.add(valueBytes);
  if (tail != null) {
    out.add(tail);
  }
  return out.toBytes();
}

(String, int) _readU16LenString(Uint8List body, int offset) {
  final len = body.buffer.asByteData(body.offsetInBytes + offset).getUint16(0);
  final value = utf8.decode(
    Uint8List.sublistView(body, offset + 2, offset + 2 + len),
  );
  return (value, offset + 2 + len);
}

class JoinRequestMessage extends SessionWireMessage {
  final String deviceId;
  final String code;

  const JoinRequestMessage({required this.deviceId, required this.code});

  @override
  Uint8List encode() {
    final deviceIdBytes = utf8.encode(deviceId);
    final codeBytes = utf8.encode(code);
    final out = BytesBuilder();
    out.addByte(0x01);
    out.add(
        (ByteData(2)..setUint16(0, deviceIdBytes.length)).buffer.asUint8List());
    out.add(deviceIdBytes);
    out.add((ByteData(2)..setUint16(0, codeBytes.length)).buffer.asUint8List());
    out.add(codeBytes);
    return out.toBytes();
  }

  static JoinRequestMessage _decodeBody(Uint8List body) {
    final (deviceId, next) = _readU16LenString(body, 0);
    final (code, _) = _readU16LenString(body, next);
    return JoinRequestMessage(deviceId: deviceId, code: code);
  }
}

class JoinRejectedMessage extends SessionWireMessage {
  final String reasonCode;

  const JoinRejectedMessage({required this.reasonCode});

  @override
  Uint8List encode() => _withU16LenString(0x02, reasonCode);

  static JoinRejectedMessage _decodeBody(Uint8List body) {
    final (reasonCode, _) = _readU16LenString(body, 0);
    return JoinRejectedMessage(reasonCode: reasonCode);
  }
}

class HandshakeInitMessage extends SessionWireMessage {
  final Uint8List publicKey;

  const HandshakeInitMessage({required this.publicKey});

  @override
  Uint8List encode() {
    final out = BytesBuilder();
    out.addByte(0x03);
    out.add((ByteData(2)..setUint16(0, publicKey.length)).buffer.asUint8List());
    out.add(publicKey);
    return out.toBytes();
  }

  static HandshakeInitMessage _decodeBody(Uint8List body) {
    final len = body.buffer.asByteData(body.offsetInBytes).getUint16(0);
    final key = Uint8List.sublistView(body, 2, 2 + len);
    return HandshakeInitMessage(publicKey: key);
  }
}

class HandshakeResponseMessage extends SessionWireMessage {
  final Uint8List publicKey;

  const HandshakeResponseMessage({required this.publicKey});

  @override
  Uint8List encode() {
    final out = BytesBuilder();
    out.addByte(0x04);
    out.add((ByteData(2)..setUint16(0, publicKey.length)).buffer.asUint8List());
    out.add(publicKey);
    return out.toBytes();
  }

  static HandshakeResponseMessage _decodeBody(Uint8List body) {
    final len = body.buffer.asByteData(body.offsetInBytes).getUint16(0);
    final key = Uint8List.sublistView(body, 2, 2 + len);
    return HandshakeResponseMessage(publicKey: key);
  }
}

class EnvelopeMessage extends SessionWireMessage {
  final bool requiresMasterRole;
  final ParticipantId senderId;
  final int sequence;
  final Uint8List hmac;
  final Uint8List payload;

  const EnvelopeMessage({
    required this.requiresMasterRole,
    required this.senderId,
    required this.sequence,
    required this.hmac,
    required this.payload,
  });

  @override
  Uint8List encode() {
    final senderIdBytes = utf8.encode(senderId.value);
    final out = BytesBuilder();
    out.addByte(0x05);
    out.addByte(requiresMasterRole ? 1 : 0);
    out.add(
        (ByteData(2)..setUint16(0, senderIdBytes.length)).buffer.asUint8List());
    out.add(senderIdBytes);
    out.add((ByteData(8)..setInt64(0, sequence)).buffer.asUint8List());
    out.add(hmac);
    out.add((ByteData(4)..setUint32(0, payload.length)).buffer.asUint8List());
    out.add(payload);
    return out.toBytes();
  }

  static EnvelopeMessage _decodeBody(Uint8List body) {
    var offset = 0;
    final requiresMasterRole = body[offset] == 1;
    offset += 1;
    final (senderId, afterSender) = _readU16LenString(body, offset);
    offset = afterSender;
    final sequence =
        body.buffer.asByteData(body.offsetInBytes + offset).getInt64(0);
    offset += 8;
    final hmac = Uint8List.sublistView(body, offset, offset + 32);
    offset += 32;
    final payloadLen =
        body.buffer.asByteData(body.offsetInBytes + offset).getUint32(0);
    offset += 4;
    final payload = Uint8List.sublistView(body, offset, offset + payloadLen);
    return EnvelopeMessage(
      requiresMasterRole: requiresMasterRole,
      senderId: ParticipantId(senderId),
      sequence: sequence,
      hmac: hmac,
      payload: payload,
    );
  }
}
