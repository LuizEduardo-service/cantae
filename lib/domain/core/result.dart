import 'package:cantae/domain/core/failures.dart';

sealed class Result<S, F extends Failure> {
  const Result();

  const factory Result.success(S value) = _Ok<S, F>;
  const factory Result.failure(F failure) = _Err<S, F>;

  T when<T>({
    required T Function(S value) success,
    required T Function(F failure) failure,
  }) =>
      switch (this) {
        _Ok<S, F>(:final value) => success(value),
        _Err<S, F>(failure: final err) => failure(err),
      };

  bool get isSuccess => this is _Ok<S, F>;
  bool get isFailure => this is _Err<S, F>;
}

final class _Ok<S, F extends Failure> extends Result<S, F> {
  final S value;
  const _Ok(this.value);
}

final class _Err<S, F extends Failure> extends Result<S, F> {
  final F failure;
  const _Err(this.failure);
}
