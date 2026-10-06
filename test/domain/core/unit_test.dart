import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/domain/core/unit.dart';

void main() {
  group('Unit', () {
    test('two instances are equal', () {
      expect(const Unit(), equals(const Unit()));
    });

    test('two instances share the same hashCode', () {
      expect(const Unit().hashCode, equals(const Unit().hashCode));
    });

    test('is const-constructible', () {
      const u = Unit();
      expect(u, isA<Unit>());
    });
  });
}
