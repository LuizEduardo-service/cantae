import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/core/failures.dart';

void main() {
  group('Result - Success', () {
    test('Success carries and exposes its value via when()', () {
      const result = Result<int, NotFoundFailure>.success(42);

      final extracted = result.when(
        success: (v) => v,
        failure: (_) => -1,
      );

      expect(extracted, equals(42));
    });
  });

  group('Result - Failure', () {
    test('Failure carries and exposes its typed Failure via when()', () {
      final failure = NotFoundFailure(code: 'song.not_found');
      final result = Result<int, NotFoundFailure>.failure(failure);

      final extracted = result.when(
        success: (_) => null,
        failure: (f) => f.code,
      );

      expect(extracted, equals('song.not_found'));
    });

    test('Failure.code must not be empty — AssertionError in debug mode', () {
      expect(
        () => NotFoundFailure(code: ''),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('Failure subtypes', () {
    test('NotFoundFailure instantiates with a non-empty code', () {
      final f = NotFoundFailure(code: 'x');
      expect(f.code, isNotEmpty);
    });

    test('ValidationFailure instantiates with a non-empty code', () {
      final f = ValidationFailure(code: 'validation.required');
      expect(f.code, isNotEmpty);
    });

    test('StorageFailure instantiates with a non-empty code', () {
      final f = StorageFailure(code: 'storage.write_failed');
      expect(f.code, isNotEmpty);
    });

    test('NetworkFailure instantiates with a non-empty code', () {
      final f = NetworkFailure(code: 'network.timeout');
      expect(f.code, isNotEmpty);
    });
  });
}
