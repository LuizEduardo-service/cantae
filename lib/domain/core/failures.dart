abstract class Failure {
  final String code;

  Failure({required this.code}) : assert(code.isNotEmpty, 'Failure.code must not be empty');

  @override
  String toString() => '${runtimeType}(code: $code)';
}

class NotFoundFailure extends Failure {
  NotFoundFailure({required super.code});
}

class ValidationFailure extends Failure {
  ValidationFailure({required super.code});
}

class StorageFailure extends Failure {
  StorageFailure({required super.code});
}

class NetworkFailure extends Failure {
  NetworkFailure({required super.code});
}
