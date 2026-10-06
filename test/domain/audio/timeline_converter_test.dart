import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/domain/audio/timeline_converter.dart';

void main() {
  group('TimelineConverter.toTrackLocal', () {
    test('returns timeline minus delay when track has started', () {
      expect(TimelineConverter.toTrackLocal(timelineMs: 1000, startDelayMs: 300), equals(700));
    });

    test('returns 0 when timeline is before track start', () {
      expect(TimelineConverter.toTrackLocal(timelineMs: 200, startDelayMs: 300), equals(0));
    });

    test('returns 0 at exact track start boundary', () {
      expect(TimelineConverter.toTrackLocal(timelineMs: 300, startDelayMs: 300), equals(0));
    });

    test('negative startDelayMs throws AssertionError', () {
      // ignore: prefer_const_constructors
      expect(
        () => TimelineConverter.toTrackLocal(timelineMs: 1000, startDelayMs: -1),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('TimelineConverter.toTimeline', () {
    test('returns track local plus delay', () {
      expect(TimelineConverter.toTimeline(trackLocalMs: 700, startDelayMs: 300), equals(1000));
    });

    test('negative startDelayMs throws AssertionError', () {
      expect(
        () => TimelineConverter.toTimeline(trackLocalMs: 700, startDelayMs: -1),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('TimelineConverter roundtrip', () {
    test('toTimeline(toTrackLocal(t, d), d) == t for t >= d', () {
      const cases = [
        (t: 1000, d: 300),
        (t: 5000, d: 0),
        (t: 500, d: 500),
        (t: 10000, d: 2500),
      ];
      for (final c in cases) {
        final local = TimelineConverter.toTrackLocal(timelineMs: c.t, startDelayMs: c.d);
        final back = TimelineConverter.toTimeline(trackLocalMs: local, startDelayMs: c.d);
        expect(back, equals(c.t), reason: 'roundtrip failed for t=${c.t} d=${c.d}');
      }
    });
  });
}
