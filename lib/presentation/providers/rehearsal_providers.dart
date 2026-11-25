import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/drift_rehearsal_repository.dart';
import '../../domain/core/failures.dart';
import '../../domain/core/result.dart';
import '../../domain/entities/rehearsal_log.dart';
import '../../domain/repositories/rehearsal_repository.dart';
import 'library_providers.dart';
import 'song_detail_providers.dart';
import 'song_repository_provider.dart';

/// Rehearsal history on this device (RF39, RF40).
final rehearsalRepositoryProvider = Provider<RehearsalRepository>(
  (ref) => DriftRehearsalRepository(ref.watch(appDatabaseProvider)),
);

/// The current time. Tests override it to measure a session.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// One song's rehearsals, newest first.
final rehearsalLogsProvider = FutureProvider.autoDispose
    .family<Result<List<RehearsalLog>, StorageFailure>, String>(
  (ref, songId) => ref.watch(rehearsalRepositoryProvider).getBySong(songId),
);

/// App-scoped, so it still works after the screen that recorded the session
/// is gone (rehearsal-history design, approach A).
final rehearsalRecorderProvider = Provider<RehearsalRecorder>(
  RehearsalRecorder.new,
);

class RehearsalRecorder {
  RehearsalRecorder(this._ref);

  final Ref _ref;

  /// Saves [log], marks its song as rehearsed at the end of the session
  /// (HIST-05) and refreshes what shows them. Never throws: the singer has
  /// already left the screen, so a failure loses the rehearsal silently
  /// (HIST-07).
  Future<void> record(RehearsalLog log) async {
    try {
      final saved = await _ref.read(rehearsalRepositoryProvider).add(log);
      if (saved.isFailure) return;
      _ref.invalidate(rehearsalLogsProvider(log.songId));
      await _ref
          .read(songRepositoryProvider)
          .markRehearsed(log.songId, log.endedAt);
      _ref
        ..invalidate(songsProvider)
        ..invalidate(songByIdProvider(log.songId));
    } catch (_) {
      // Nothing to show: see the doc comment.
    }
  }
}
