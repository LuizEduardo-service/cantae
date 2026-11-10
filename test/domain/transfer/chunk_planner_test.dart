import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/domain/transfer/chunk_planner.dart';

void main() {
  group('ChunkPlanner.chunkCount', () {
    test('a file whose size is an exact multiple of the chunk size', () {
      final count = ChunkPlanner.chunkCount(
        totalSizeBytes: 64 * 1024 * 3,
        chunkSize: 64 * 1024,
      );
      expect(count, equals(3));
    });

    test('a file with a remainder chunk rounds up to one extra chunk', () {
      final count = ChunkPlanner.chunkCount(
        totalSizeBytes: 64 * 1024 * 2 + 1,
        chunkSize: 64 * 1024,
      );
      expect(count, equals(3));
    });

    test('a zero-size file requires zero chunks', () {
      final count = ChunkPlanner.chunkCount(
        totalSizeBytes: 0,
        chunkSize: 64 * 1024,
      );
      expect(count, equals(0));
    });
  });

  group('ChunkPlanner.resumeFromChunkIndex', () {
    test('no chunk acked yet (-1) resumes at chunk 0 (XFER-04)', () {
      expect(
        ChunkPlanner.resumeFromChunkIndex(lastAckedChunkIndex: -1),
        equals(0),
      );
    });

    test('chunk N acked resumes at chunk N+1 (XFER-04)', () {
      expect(
        ChunkPlanner.resumeFromChunkIndex(lastAckedChunkIndex: 5),
        equals(6),
      );
    });
  });

  group('ChunkPlanner.exceedsMaxSize (100 MB cap edge case)', () {
    test('a file exactly at the 100 MB cap does not exceed it', () {
      expect(
        ChunkPlanner.exceedsMaxSize(ChunkPlanner.maxTransferableSizeBytes),
        isFalse,
      );
    });

    test('a file 1 byte under the cap does not exceed it', () {
      expect(
        ChunkPlanner.exceedsMaxSize(ChunkPlanner.maxTransferableSizeBytes - 1),
        isFalse,
      );
    });

    test('a file 1 byte over the cap exceeds it', () {
      expect(
        ChunkPlanner.exceedsMaxSize(ChunkPlanner.maxTransferableSizeBytes + 1),
        isTrue,
      );
    });
  });
}
