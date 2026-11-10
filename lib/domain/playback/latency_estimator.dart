abstract final class LatencyEstimator {
  static int estimateOneWayDelayMs({
    required int sentAtEpochMs,
    required int echoedAtEpochMs,
    required int receivedBackAtEpochMs,
  }) {
    assert(
      receivedBackAtEpochMs >= sentAtEpochMs,
      'receivedBackAtEpochMs must be >= sentAtEpochMs (invalid clock input)',
    );
    return (receivedBackAtEpochMs - sentAtEpochMs) ~/ 2;
  }
}
