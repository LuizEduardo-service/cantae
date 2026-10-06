import 'package:cantae/domain/core/failures.dart';

sealed class Result<S, F extends Failure> {
  const Result();

  const factory Result.success(S value) = Success<S, F>;
  const factory Result.failure(F failure) = Failure<S, F>;

  T when<T>({
    required T Function(S value) success,
    required T Function(F failure) failure,
  }) {
    return switch (this) {
      Success<S, F>(:final value) => success(value),
      Failure<S, F>(:final failure) => failure(failure),
    };
  }

  bool get isSuccess => this is Success<S, F>;
  bool get isFailure => this is Failure<S, F>;
}

final class Success<S, F extends Failure> extends Result<S, F> {
  final S value;
  const Success(this.value);
}

final class Failure<S, F extends Failure> extends Result<S, F> {
  final F failure;
  const Failure(this.failure);
}
