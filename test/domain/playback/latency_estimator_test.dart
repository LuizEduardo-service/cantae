import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/domain/playback/latency_estimator.dart';

void main() {
  group('LatencyEstimator.estimateOneWayDelayMs (SYNC-02)', () {
    test('zero RTT yields zero one-way delay', () {
      final delay = LatencyEstimator.estimateOneWayDelayMs(
        sentAtEpochMs: 1000,
        echoedAtEpochMs: 1000,
        receivedBackAtEpochMs: 1000,
      );
      expect(delay, equals(0));
    });

    test('a typical LAN round trip of a few ms halves to the one-way delay',
        () {
      final delay = LatencyEstimator.estimateOneWayDelayMs(
        sentAtEpochMs: 1000,
        echoedAtEpochMs: 1003,
        receivedBackAtEpochMs: 1006,
      );
      expect(delay, equals(3));
    });

    test(
        'echoed-before-sent clock skew (receivedBackAtEpochMs < sentAtEpochMs) is an asserted-invalid input',
        () {
      expect(
        () => LatencyEstimator.estimateOneWayDelayMs(
          sentAtEpochMs: 1000,
          echoedAtEpochMs: 998,
          receivedBackAtEpochMs: 999,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
