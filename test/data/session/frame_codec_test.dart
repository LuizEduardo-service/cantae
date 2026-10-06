import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/data/session/frame_codec.dart';

void main() {
  group('FrameReassembler', () {
    test('a single chunk containing exactly one frame yields that frame', () {
      final reassembler = FrameReassembler();
      final frame = encodeFrame(Uint8List.fromList([1, 2, 3]));

      final frames = reassembler.addChunk(frame);

      expect(frames.length, equals(1));
      expect(frames.first, equals([1, 2, 3]));
    });

    test('a frame split across two chunks is only emitted once both arrive',
        () {
      final reassembler = FrameReassembler();
      final frame = encodeFrame(Uint8List.fromList([10, 20, 30, 40]));

      final firstChunkFrames = reassembler.addChunk(
        Uint8List.sublistView(frame, 0, 5),
      );
      expect(firstChunkFrames, isEmpty);

      final secondChunkFrames = reassembler.addChunk(
        Uint8List.sublistView(frame, 5),
      );
      expect(secondChunkFrames.length, equals(1));
      expect(secondChunkFrames.first, equals([10, 20, 30, 40]));
    });

    test(
        'two frames concatenated in a single chunk both get reassembled, in order',
        () {
      final reassembler = FrameReassembler();
      final first = encodeFrame(Uint8List.fromList([1]));
      final second = encodeFrame(Uint8List.fromList([2, 2]));
      final combined = Uint8List.fromList([...first, ...second]);

      final frames = reassembler.addChunk(combined);

      expect(frames.length, equals(2));
      expect(frames[0], equals([1]));
      expect(frames[1], equals([2, 2]));
    });
  });
}
