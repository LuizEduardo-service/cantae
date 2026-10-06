import 'dart:typed_data';

Uint8List encodeFrame(Uint8List payload) {
  final frame = Uint8List(4 + payload.length);
  frame.buffer.asByteData().setUint32(0, payload.length);
  frame.setRange(4, frame.length, payload);
  return frame;
}

/// Buffers raw byte chunks from a TCP stream and reassembles complete,
/// length-prefixed frame payloads. A single chunk may contain a partial
/// frame, exactly one frame, or several frames concatenated together.
class FrameReassembler {
  final BytesBuilder _buffer = BytesBuilder();

  List<Uint8List> addChunk(Uint8List chunk) {
    _buffer.add(chunk);
    final frames = <Uint8List>[];
    var pending = Uint8List.fromList(_buffer.takeBytes());

    while (true) {
      if (pending.length < 4) {
        break;
      }
      final frameLength = pending.buffer
          .asByteData(
            pending.offsetInBytes,
          )
          .getUint32(0);
      final totalLength = 4 + frameLength;
      if (pending.length < totalLength) {
        break;
      }
      frames.add(Uint8List.sublistView(pending, 4, totalLength));
      pending = Uint8List.sublistView(pending, totalLength);
    }

    _buffer.add(pending);
    return frames;
  }
}
