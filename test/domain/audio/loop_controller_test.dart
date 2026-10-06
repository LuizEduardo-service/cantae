import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/domain/audio/loop_controller.dart';

void main() {
  group('LoopController.isValid', () {
    test('valid bounds returns true', () {
      const lc = LoopController(startMs: 1000, endMs: 5000, maxMs: 10000);
      expect(lc.isValid, isTrue);
    });

    test('startMs equal to endMs returns false', () {
      const lc = LoopController(startMs: 2000, endMs: 2000, maxMs: 10000);
      expect(lc.isValid, isFalse);
    });

    test('startMs greater than endMs returns false', () {
      const lc = LoopController(startMs: 3000, endMs: 2000, maxMs: 10000);
      expect(lc.isValid, isFalse);
    });

    test('startMs below 0 returns false', () {
      const lc = LoopController(startMs: -1, endMs: 5000, maxMs: 10000);
      expect(lc.isValid, isFalse);
    });

    test('endMs greater than maxMs returns false', () {
      const lc = LoopController(startMs: 1000, endMs: 11000, maxMs: 10000);
      expect(lc.isValid, isFalse);
    });

    test('endMs equal to maxMs returns true (full-song loop)', () {
      const lc = LoopController(startMs: 0, endMs: 10000, maxMs: 10000);
      expect(lc.isValid, isTrue);
    });
  });

  group('LoopController.shouldReposition', () {
    test('currentMs at endMs triggers reposition', () {
      const lc = LoopController(startMs: 1000, endMs: 5000, maxMs: 10000);
      expect(lc.shouldReposition(5000), isTrue);
    });

    test('currentMs past endMs triggers reposition', () {
      const lc = LoopController(startMs: 1000, endMs: 5000, maxMs: 10000);
      expect(lc.shouldReposition(5001), isTrue);
    });

    test('currentMs before endMs does not trigger reposition', () {
      const lc = LoopController(startMs: 1000, endMs: 5000, maxMs: 10000);
      expect(lc.shouldReposition(4999), isFalse);
    });

    test('invalid loop never triggers reposition', () {
      const lc = LoopController(startMs: 3000, endMs: 2000, maxMs: 10000);
      expect(lc.shouldReposition(5000), isFalse);
    });
  });

  group('LoopController.repositionTarget', () {
    test('returns startMs for a valid loop', () {
      const lc = LoopController(startMs: 1000, endMs: 5000, maxMs: 10000);
      expect(lc.repositionTarget, equals(1000));
    });
  });
}
