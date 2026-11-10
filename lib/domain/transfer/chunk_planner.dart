abstract final class ChunkPlanner {
  static const int maxTransferableSizeBytes = 100 * 1024 * 1024;

  static int chunkCount({required int totalSizeBytes, required int chunkSize}) {
    assert(totalSizeBytes >= 0, 'totalSizeBytes must be >= 0');
    assert(chunkSize > 0, 'chunkSize must be > 0');
    if (totalSizeBytes == 0) {
      return 0;
    }
    return (totalSizeBytes + chunkSize - 1) ~/ chunkSize;
  }

  static int resumeFromChunkIndex({required int lastAckedChunkIndex}) {
    if (lastAckedChunkIndex < 0) {
      return 0;
    }
    return lastAckedChunkIndex + 1;
  }

  static bool exceedsMaxSize(int totalSizeBytes) {
    assert(totalSizeBytes >= 0, 'totalSizeBytes must be >= 0');
    return totalSizeBytes > maxTransferableSizeBytes;
  }
}
