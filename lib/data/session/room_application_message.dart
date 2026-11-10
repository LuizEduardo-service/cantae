import 'dart:convert';
import 'dart:typed_data';

/// Tag-prefixed application-level message family carried inside the
/// already-authenticated `Envelope.payload` bytes (see design.md's "Approach
/// Exploration: how to carry the new protocol"). This is a separate wire
/// family from `SessionWireMessage` — its tag space (0x01-0x0B) is scoped to
/// this file only, never mixed with the session-level tags.
abstract class RoomApplicationMessage {
  const RoomApplicationMessage();

  Uint8List encode();

  static RoomApplicationMessage decode(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw ArgumentError('Empty RoomApplicationMessage bytes');
    }
    final tag = bytes[0];
    final body = Uint8List.sublistView(bytes, 1);
    switch (tag) {
      case 0x01:
        return TransferBeginMessage._decodeBody(body);
      case 0x02:
        return ChunkDataMessage._decodeBody(body);
      case 0x03:
        return ChunkAckMessage._decodeBody(body);
      case 0x04:
        return TransferCompleteMessage._decodeBody(body);
      case 0x05:
        return PlayCommandMessage._decodeBody(body);
      case 0x06:
        return PauseCommandMessage._decodeBody(body);
      case 0x07:
        return StopCommandMessage._decodeBody(body);
      case 0x08:
        return LoopRepositionMessage._decodeBody(body);
      case 0x09:
        return LatencyProbeMessage._decodeBody(body);
      case 0x0A:
        return LatencyProbeReplyMessage._decodeBody(body);
      case 0x0B:
        return PlaybackSnapshotMessage._decodeBody(body);
      default:
        throw ArgumentError('Unknown RoomApplicationMessage tag: $tag');
    }
  }
}

Uint8List _withU16LenString(int tag, String value, [Uint8List? tail]) {
  final valueBytes = utf8.encode(value);
  final out = BytesBuilder();
  out.addByte(tag);
  out.add((ByteData(2)..setUint16(0, valueBytes.length)).buffer.asUint8List());
  out.add(valueBytes);
  if (tail != null) {
    out.add(tail);
  }
  return out.toBytes();
}

(String, int) _readU16LenString(Uint8List body, int offset) {
  final len =
      body.buffer.asByteData(body.offsetInBytes + offset).getUint16(0);
  final value = utf8.decode(
    Uint8List.sublistView(body, offset + 2, offset + 2 + len),
  );
  return (value, offset + 2 + len);
}

Uint8List _u16LenStringBytes(String value) {
  final valueBytes = utf8.encode(value);
  final out = BytesBuilder();
  out.add((ByteData(2)..setUint16(0, valueBytes.length)).buffer.asUint8List());
  out.add(valueBytes);
  return out.toBytes();
}

Uint8List _u32LenBytesBytes(Uint8List value) {
  final out = BytesBuilder();
  out.add((ByteData(4)..setUint32(0, value.length)).buffer.asUint8List());
  out.add(value);
  return out.toBytes();
}

(Uint8List, int) _readU32LenBytes(Uint8List body, int offset) {
  final len =
      body.buffer.asByteData(body.offsetInBytes + offset).getUint32(0);
  final value = Uint8List.sublistView(body, offset + 4, offset + 4 + len);
  return (value, offset + 4 + len);
}

Uint8List _optionalU16LenStringBytes(String? value) {
  final out = BytesBuilder();
  if (value == null) {
    out.addByte(0);
    return out.toBytes();
  }
  out.addByte(1);
  out.add(_u16LenStringBytes(value));
  return out.toBytes();
}

(String?, int) _readOptionalU16LenString(Uint8List body, int offset) {
  final present = body[offset] == 1;
  if (!present) {
    return (null, offset + 1);
  }
  final (value, next) = _readU16LenString(body, offset + 1);
  return (value, next);
}

class TransferBeginMessage extends RoomApplicationMessage {
  final String songId;
  final String trackId;
  final int totalSizeBytes;
  final String sha256Declared;
  final int chunkSize;

  const TransferBeginMessage({
    required this.songId,
    required this.trackId,
    required this.totalSizeBytes,
    required this.sha256Declared,
    required this.chunkSize,
  });

  @override
  Uint8List encode() {
    final out = BytesBuilder();
    out.addByte(0x01);
    out.add(_u16LenStringBytes(songId));
    out.add(_u16LenStringBytes(trackId));
    out.add((ByteData(8)..setUint64(0, totalSizeBytes)).buffer.asUint8List());
    out.add(_u16LenStringBytes(sha256Declared));
    out.add((ByteData(4)..setUint32(0, chunkSize)).buffer.asUint8List());
    return out.toBytes();
  }

  static TransferBeginMessage _decodeBody(Uint8List body) {
    var offset = 0;
    final (songId, afterSong) = _readU16LenString(body, offset);
    offset = afterSong;
    final (trackId, afterTrack) = _readU16LenString(body, offset);
    offset = afterTrack;
    final totalSizeBytes =
        body.buffer.asByteData(body.offsetInBytes + offset).getUint64(0);
    offset += 8;
    final (sha256Declared, afterHash) = _readU16LenString(body, offset);
    offset = afterHash;
    final chunkSize =
        body.buffer.asByteData(body.offsetInBytes + offset).getUint32(0);
    return TransferBeginMessage(
      songId: songId,
      trackId: trackId,
      totalSizeBytes: totalSizeBytes,
      sha256Declared: sha256Declared,
      chunkSize: chunkSize,
    );
  }
}

class ChunkDataMessage extends RoomApplicationMessage {
  final String trackId;
  final int chunkIndex;
  final Uint8List bytes;

  const ChunkDataMessage({
    required this.trackId,
    required this.chunkIndex,
    required this.bytes,
  });

  @override
  Uint8List encode() {
    final out = BytesBuilder();
    out.addByte(0x02);
    out.add(_u16LenStringBytes(trackId));
    out.add((ByteData(4)..setUint32(0, chunkIndex)).buffer.asUint8List());
    out.add(_u32LenBytesBytes(bytes));
    return out.toBytes();
  }

  static ChunkDataMessage _decodeBody(Uint8List body) {
    var offset = 0;
    final (trackId, afterTrack) = _readU16LenString(body, offset);
    offset = afterTrack;
    final chunkIndex =
        body.buffer.asByteData(body.offsetInBytes + offset).getUint32(0);
    offset += 4;
    final (chunkBytes, _) = _readU32LenBytes(body, offset);
    return ChunkDataMessage(
      trackId: trackId,
      chunkIndex: chunkIndex,
      bytes: chunkBytes,
    );
  }
}

class ChunkAckMessage extends RoomApplicationMessage {
  final String trackId;
  final int chunkIndex;

  const ChunkAckMessage({required this.trackId, required this.chunkIndex});

  @override
  Uint8List encode() {
    final out = BytesBuilder();
    out.addByte(0x03);
    out.add(_u16LenStringBytes(trackId));
    out.add((ByteData(4)..setUint32(0, chunkIndex)).buffer.asUint8List());
    return out.toBytes();
  }

  static ChunkAckMessage _decodeBody(Uint8List body) {
    final (trackId, afterTrack) = _readU16LenString(body, 0);
    final chunkIndex = body.buffer
        .asByteData(body.offsetInBytes + afterTrack)
        .getUint32(0);
    return ChunkAckMessage(trackId: trackId, chunkIndex: chunkIndex);
  }
}

class TransferCompleteMessage extends RoomApplicationMessage {
  final String trackId;
  final bool accepted;
  final String? failureCode;

  const TransferCompleteMessage({
    required this.trackId,
    required this.accepted,
    this.failureCode,
  });

  @override
  Uint8List encode() {
    final out = BytesBuilder();
    out.addByte(0x04);
    out.add(_u16LenStringBytes(trackId));
    out.addByte(accepted ? 1 : 0);
    out.add(_optionalU16LenStringBytes(failureCode));
    return out.toBytes();
  }

  static TransferCompleteMessage _decodeBody(Uint8List body) {
    var offset = 0;
    final (trackId, afterTrack) = _readU16LenString(body, offset);
    offset = afterTrack;
    final accepted = body[offset] == 1;
    offset += 1;
    final (failureCode, _) = _readOptionalU16LenString(body, offset);
    return TransferCompleteMessage(
      trackId: trackId,
      accepted: accepted,
      failureCode: failureCode,
    );
  }
}

class PlayCommandMessage extends RoomApplicationMessage {
  final String songId;
  final int masterSendEpochMs;

  const PlayCommandMessage({
    required this.songId,
    required this.masterSendEpochMs,
  });

  @override
  Uint8List encode() {
    final out = BytesBuilder();
    out.addByte(0x05);
    out.add(_u16LenStringBytes(songId));
    out.add(
        (ByteData(8)..setInt64(0, masterSendEpochMs)).buffer.asUint8List());
    return out.toBytes();
  }

  static PlayCommandMessage _decodeBody(Uint8List body) {
    final (songId, afterSong) = _readU16LenString(body, 0);
    final masterSendEpochMs = body.buffer
        .asByteData(body.offsetInBytes + afterSong)
        .getInt64(0);
    return PlayCommandMessage(
        songId: songId, masterSendEpochMs: masterSendEpochMs);
  }
}

class PauseCommandMessage extends RoomApplicationMessage {
  final int masterSendEpochMs;

  const PauseCommandMessage({required this.masterSendEpochMs});

  @override
  Uint8List encode() {
    final out = BytesBuilder();
    out.addByte(0x06);
    out.add(
        (ByteData(8)..setInt64(0, masterSendEpochMs)).buffer.asUint8List());
    return out.toBytes();
  }

  static PauseCommandMessage _decodeBody(Uint8List body) {
    final masterSendEpochMs =
        body.buffer.asByteData(body.offsetInBytes).getInt64(0);
    return PauseCommandMessage(masterSendEpochMs: masterSendEpochMs);
  }
}

class StopCommandMessage extends RoomApplicationMessage {
  final int masterSendEpochMs;

  const StopCommandMessage({required this.masterSendEpochMs});

  @override
  Uint8List encode() {
    final out = BytesBuilder();
    out.addByte(0x07);
    out.add(
        (ByteData(8)..setInt64(0, masterSendEpochMs)).buffer.asUint8List());
    return out.toBytes();
  }

  static StopCommandMessage _decodeBody(Uint8List body) {
    final masterSendEpochMs =
        body.buffer.asByteData(body.offsetInBytes).getInt64(0);
    return StopCommandMessage(masterSendEpochMs: masterSendEpochMs);
  }
}

class LoopRepositionMessage extends RoomApplicationMessage {
  final int masterSendEpochMs;

  const LoopRepositionMessage({required this.masterSendEpochMs});

  @override
  Uint8List encode() {
    final out = BytesBuilder();
    out.addByte(0x08);
    out.add(
        (ByteData(8)..setInt64(0, masterSendEpochMs)).buffer.asUint8List());
    return out.toBytes();
  }

  static LoopRepositionMessage _decodeBody(Uint8List body) {
    final masterSendEpochMs =
        body.buffer.asByteData(body.offsetInBytes).getInt64(0);
    return LoopRepositionMessage(masterSendEpochMs: masterSendEpochMs);
  }
}

class LatencyProbeMessage extends RoomApplicationMessage {
  final String probeId;
  final int masterSendEpochMs;

  const LatencyProbeMessage({
    required this.probeId,
    required this.masterSendEpochMs,
  });

  @override
  Uint8List encode() {
    final out = BytesBuilder();
    out.addByte(0x09);
    out.add(_u16LenStringBytes(probeId));
    out.add(
        (ByteData(8)..setInt64(0, masterSendEpochMs)).buffer.asUint8List());
    return out.toBytes();
  }

  static LatencyProbeMessage _decodeBody(Uint8List body) {
    final (probeId, afterProbe) = _readU16LenString(body, 0);
    final masterSendEpochMs = body.buffer
        .asByteData(body.offsetInBytes + afterProbe)
        .getInt64(0);
    return LatencyProbeMessage(
        probeId: probeId, masterSendEpochMs: masterSendEpochMs);
  }
}

class LatencyProbeReplyMessage extends RoomApplicationMessage {
  final String probeId;

  const LatencyProbeReplyMessage({required this.probeId});

  @override
  Uint8List encode() => _withU16LenString(0x0A, probeId);

  static LatencyProbeReplyMessage _decodeBody(Uint8List body) {
    final (probeId, _) = _readU16LenString(body, 0);
    return LatencyProbeReplyMessage(probeId: probeId);
  }
}

class PlaybackSnapshotMessage extends RoomApplicationMessage {
  final String? songId;
  final String state;

  const PlaybackSnapshotMessage({required this.songId, required this.state});

  @override
  Uint8List encode() {
    final out = BytesBuilder();
    out.addByte(0x0B);
    out.add(_optionalU16LenStringBytes(songId));
    out.add(_u16LenStringBytes(state));
    return out.toBytes();
  }

  static PlaybackSnapshotMessage _decodeBody(Uint8List body) {
    final (songId, afterSong) = _readOptionalU16LenString(body, 0);
    final (state, _) = _readU16LenString(body, afterSong);
    return PlaybackSnapshotMessage(songId: songId, state: state);
  }
}
