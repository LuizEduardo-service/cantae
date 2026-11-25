import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/core/failures.dart';
import '../../domain/core/result.dart';
import '../../domain/core/unit.dart';
import '../../domain/entities/rehearsal_log.dart';
import 'rehearsal_providers.dart';
import 'song_repository_provider.dart';

const String deleteRehearsalsFailedMessage =
    'Não foi possível apagar os ensaios.';

enum RehearsalHistoryStatus { loading, notFound, error, ready }

/// State for the "Ensaios" screen (UI_SPEC §6.16).
class RehearsalHistoryState {
  const RehearsalHistoryState({
    required this.status,
    this.songName = '',
    this.logs = const [],
    this.deleting = false,
    this.deleteError,
  });

  final RehearsalHistoryStatus status;
  final String songName;

  /// Newest first.
  final List<RehearsalLog> logs;
  final bool deleting;
  final String? deleteError;

  int get count => logs.length;
  int get totalDurationMs => logs.fold(0, (sum, l) => sum + l.durationMs);
  int get totalLoops => logs.fold(0, (sum, l) => sum + l.loopCount);

  RehearsalHistoryState copyWith({
    RehearsalHistoryStatus? status,
    String? songName,
    List<RehearsalLog>? logs,
    bool? deleting,
    String? deleteError,
    bool clearDeleteError = false,
  }) =>
      RehearsalHistoryState(
        status: status ?? this.status,
        songName: songName ?? this.songName,
        logs: logs ?? this.logs,
        deleting: deleting ?? this.deleting,
        deleteError:
            clearDeleteError ? null : (deleteError ?? this.deleteError),
      );
}

final rehearsalHistoryProvider = StateNotifierProvider.autoDispose
    .family<RehearsalHistoryNotifier, RehearsalHistoryState, String>(
  (ref, songId) => RehearsalHistoryNotifier(ref, songId),
);

class RehearsalHistoryNotifier extends StateNotifier<RehearsalHistoryState> {
  RehearsalHistoryNotifier(this._ref, this._songId)
      : super(const RehearsalHistoryState(
          status: RehearsalHistoryStatus.loading,
        )) {
    _load();
  }

  final Ref _ref;
  final String _songId;

  Future<void> _load() async {
    final song = await _ref.read(songRepositoryProvider).getById(_songId);
    if (!mounted) return;
    final name = song.when(success: (s) => s.name, failure: (_) => null);
    if (name == null) {
      final missing = song.when(
        success: (_) => false,
        failure: (f) => f is NotFoundFailure,
      );
      state = state.copyWith(
        status: missing
            ? RehearsalHistoryStatus.notFound
            : RehearsalHistoryStatus.error,
      );
      return;
    }
    final logs = await _ref.read(rehearsalRepositoryProvider).getBySong(
          _songId,
        );
    if (!mounted) return;
    state = logs.when(
      success: (list) => state.copyWith(
        status: RehearsalHistoryStatus.ready,
        songName: name,
        logs: list,
      ),
      failure: (_) => state.copyWith(status: RehearsalHistoryStatus.error),
    );
  }

  void retry() {
    state = state.copyWith(status: RehearsalHistoryStatus.loading);
    _load();
  }

  /// Deletes this song's rehearsals (RF40). True on success.
  Future<bool> deleteForSong() => _delete(
        () => _ref.read(rehearsalRepositoryProvider).deleteBySong(_songId),
        invalidateEverySong: false,
      );

  /// Deletes every rehearsal on this device (RF40). True on success.
  Future<bool> deleteAll() => _delete(
        () => _ref.read(rehearsalRepositoryProvider).deleteAll(),
        invalidateEverySong: true,
      );

  Future<bool> _delete(
    Future<Result<Unit, StorageFailure>> Function() run, {
    required bool invalidateEverySong,
  }) async {
    state = state.copyWith(deleting: true, clearDeleteError: true);
    final result = await run();
    if (!mounted) return false;
    if (result.isFailure) {
      state = state.copyWith(
        deleting: false,
        deleteError: deleteRehearsalsFailedMessage,
      );
      return false;
    }
    state = state.copyWith(deleting: false, logs: const []);
    // The song detail shows the count (HIST-17).
    if (invalidateEverySong) {
      _ref.invalidate(rehearsalLogsProvider);
    } else {
      _ref.invalidate(rehearsalLogsProvider(_songId));
    }
    return true;
  }
}
