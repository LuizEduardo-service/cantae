import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/core/failures.dart';
import '../../domain/core/result.dart';
import '../../domain/entities/song.dart';
import 'song_repository_provider.dart';

/// Loads one song by id, exposing the repository's [Result] unchanged
/// (never thrown). `NotFoundFailure` and any other [Failure] both resolve
/// as `AsyncData(Result.failure(...))` — the screen (not Riverpod's error
/// channel) decides how "not found" differs from a real repository error.
/// See `design.md`'s Approach Exploration (Approach A).
final songByIdProvider = FutureProvider.family<Result<Song, Failure>, String>(
  (ref, id) async {
    final repository = ref.watch(songRepositoryProvider);
    return repository.getById(id);
  },
);
