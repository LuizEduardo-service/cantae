import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/data/session/room_application_message.dart';

void main() {
  group('RoomApplicationMessage encode/decode round-trip', () {
    test('TransferBeginMessage', () {
      const message = TransferBeginMessage(
        songId: 'song-1',
        trackId: 'track-1',
        totalSizeBytes: 123456,
        sha256Declared: 'abcdef0123456789',
        chunkSize: 65536,
      );
      final decoded = RoomApplicationMessage.decode(message.encode())
          as TransferBeginMessage;
      expect(decoded.songId, equals('song-1'));
      expect(decoded.trackId, equals('track-1'));
      expect(decoded.totalSizeBytes, equals(123456));
      expect(decoded.sha256Declared, equals('abcdef0123456789'));
      expect(decoded.chunkSize, equals(65536));
    });

    test('ChunkDataMessage', () {
      final bytes = Uint8List.fromList(List.generate(10, (i) => i));
      final message = ChunkDataMessage(
        trackId: 'track-1',
        chunkIndex: 3,
        bytes: bytes,
      );
      final decoded =
          RoomApplicationMessage.decode(message.encode()) as ChunkDataMessage;
      expect(decoded.trackId, equals('track-1'));
      expect(decoded.chunkIndex, equals(3));
      expect(decoded.bytes, equals(bytes));
    });

    test('ChunkAckMessage', () {
      const message = ChunkAckMessage(trackId: 'track-1', chunkIndex: 7);
      final decoded =
          RoomApplicationMessage.decode(message.encode()) as ChunkAckMessage;
      expect(decoded.trackId, equals('track-1'));
      expect(decoded.chunkIndex, equals(7));
    });

    test('TransferCompleteMessage with failureCode present', () {
      const message = TransferCompleteMessage(
        trackId: 'track-1',
        accepted: false,
        failureCode: 'transfer.hash-mismatch',
      );
      final decoded = RoomApplicationMessage.decode(message.encode())
          as TransferCompleteMessage;
      expect(decoded.trackId, equals('track-1'));
      expect(decoded.accepted, isFalse);
      expect(decoded.failureCode, equals('transfer.hash-mismatch'));
    });

    test('TransferCompleteMessage with null failureCode (accepted)', () {
      const message = TransferCompleteMessage(
        trackId: 'track-1',
        accepted: true,
      );
      final decoded = RoomApplicationMessage.decode(message.encode())
          as TransferCompleteMessage;
      expect(decoded.accepted, isTrue);
      expect(decoded.failureCode, isNull);
    });

    test('PlayCommandMessage', () {
      const message =
          PlayCommandMessage(songId: 'song-1', masterSendEpochMs: 1700000000);
      final decoded = RoomApplicationMessage.decode(message.encode())
          as PlayCommandMessage;
      expect(decoded.songId, equals('song-1'));
      expect(decoded.masterSendEpochMs, equals(1700000000));
    });

    test('PauseCommandMessage', () {
      const message = PauseCommandMessage(masterSendEpochMs: 42);
      final decoded = RoomApplicationMessage.decode(message.encode())
          as PauseCommandMessage;
      expect(decoded.masterSendEpochMs, equals(42));
    });

    test('StopCommandMessage', () {
      const message = StopCommandMessage(masterSendEpochMs: 99);
      final decoded = RoomApplicationMessage.decode(message.encode())
          as StopCommandMessage;
      expect(decoded.masterSendEpochMs, equals(99));
    });

    test('LoopRepositionMessage', () {
      const message = LoopRepositionMessage(masterSendEpochMs: 555);
      final decoded = RoomApplicationMessage.decode(message.encode())
          as LoopRepositionMessage;
      expect(decoded.masterSendEpochMs, equals(555));
    });

    test('LatencyProbeMessage', () {
      const message =
          LatencyProbeMessage(probeId: 'probe-1', masterSendEpochMs: 1000);
      final decoded = RoomApplicationMessage.decode(message.encode())
          as LatencyProbeMessage;
      expect(decoded.probeId, equals('probe-1'));
      expect(decoded.masterSendEpochMs, equals(1000));
    });

    test('LatencyProbeReplyMessage', () {
      const message = LatencyProbeReplyMessage(probeId: 'probe-1');
      final decoded = RoomApplicationMessage.decode(message.encode())
          as LatencyProbeReplyMessage;
      expect(decoded.probeId, equals('probe-1'));
    });

    test('PlaybackSnapshotMessage with songId present', () {
      const message =
          PlaybackSnapshotMessage(songId: 'song-1', state: 'playing');
      final decoded = RoomApplicationMessage.decode(message.encode())
          as PlaybackSnapshotMessage;
      expect(decoded.songId, equals('song-1'));
      expect(decoded.state, equals('playing'));
    });

    test('PlaybackSnapshotMessage with null songId (idle)', () {
      const message = PlaybackSnapshotMessage(songId: null, state: 'idle');
      final decoded = RoomApplicationMessage.decode(message.encode())
          as PlaybackSnapshotMessage;
      expect(decoded.songId, isNull);
      expect(decoded.state, equals('idle'));
    });
  });

  group('RoomApplicationMessage.decode rejects malformed input', () {
    test('an unknown tag byte is rejected', () {
      final bytes = Uint8List.fromList([0xFF, 0, 0]);
      expect(
        () => RoomApplicationMessage.decode(bytes),
        throwsA(anything),
      );
    });

    test('a truncated body (declared length exceeds available bytes) is rejected', () {
      // ChunkAckMessage tag (0x03) + trackId length-prefix claiming 50 bytes
      // but the body only actually contains 2 bytes after the length prefix.
      final bytes = Uint8List.fromList([0x03, 0, 50, 1, 2]);
      expect(
        () => RoomApplicationMessage.decode(bytes),
        throwsA(anything),
      );
    });

    test('an empty byte sequence is rejected', () {
      expect(
        () => RoomApplicationMessage.decode(Uint8List(0)),
        throwsA(anything),
      );
    });
  });
}
