import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/domain/core/constant_time_equals.dart';

void main() {
  group('constantTimeEquals', () {
    test('returns false when lengths differ', () {
      expect(constantTimeEquals([1, 2, 3], [1, 2]), isFalse);
    });

    test('returns true when equal length and equal bytes', () {
      expect(constantTimeEquals([1, 2, 3], [1, 2, 3]), isTrue);
    });

    test('returns false when equal length and unequal bytes', () {
      expect(constantTimeEquals([1, 2, 3], [1, 2, 4]), isFalse);
    });

    test('returns true when both are empty', () {
      expect(constantTimeEquals(<int>[], <int>[]), isTrue);
    });
  });
}
