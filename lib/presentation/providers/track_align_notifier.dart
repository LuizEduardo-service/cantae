import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/audio/audio_playback_engine.dart';
import '../../domain/audio/loop_controller.dart';
import '../../domain/core/failures.dart';
import '../../domain/core/result.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/song_track.dart';
import 'audio_playback_engine_provider.dart';
import 'library_providers.dart';
import 'song_detail_providers.dart';
import 'song_repository_provider.dart';

enum TrackAlignStatus { loading, notFound, noTracks, error, loaded }

/// State for `track-align` — see `design.md`'s `TrackAlignNotifier`.
///
/// Mute/solo/loop fields are ephemeral test state: they're never persisted
/// and never set [hasUnsavedChanges] (spec.md's Assumptions table — only
/// editing a track's offset counts as an unsaved change).
class TrackAlignState {
  const TrackAlignState({
    required this.status,
    this.song,
    this.startDelayMsByTrackId = const {},
    this.mutedByTrackId = const {},
    this.soloTrackId,
    this.loopStartMs = 0,
    this.loopEndMs = 2000,
    this.testing = false,
    this.hasUnsavedChanges = false,
    this.durationMs,
    this.saving = false,
    this.saveError,
  });

  const TrackAlignState.loading() : this(status: TrackAlignStatus.loading);

  final TrackAlignStatus status;
  final Song? song;
  final Map<String, int> startDelayMsByTrackId;
  final Map<String, bool> mutedByTrackId;
  final String? soloTrackId;
  final int loopStartMs;
  final int loopEndMs;
  final bool testing;
  final bool hasUnsavedChanges;
  final int? durationMs;
  final bool saving;
  final String? saveError;

  TrackAlignState copyWith({
    TrackAlignStatus? status,
    Song? song,
    Map<String, int>? startDelayMsByTrackId,
    Map<String, bool>? mutedByTrackId,
    String? soloTrackId,
    bool clearSolo = false,
    int? loopStartMs,
    int? loopEndMs,
    bool? testing,
    bool? hasUnsavedChanges,
    int? durationMs,
    bool? saving,
    String? saveError,
    bool clearSaveError = false,
  }) {
    return TrackAlignState(
      status: status ?? this.status,
      song: song ?? this.song,
      startDelayMsByTrackId: startDelayMsByTrackId ?? this.startDelayMsByTrackId,
      mutedByTrackId: mutedByTrackId ?? this.mutedByTrackId,
      soloTrackId: clearSolo ? null : (soloTrackId ?? this.soloTrackId),
      loopStartMs: loopStartMs ?? this.loopStartMs,
      loopEndMs: loopEndMs ?? this.loopEndMs,
      testing: testing ?? this.testing,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      durationMs: durationMs ?? this.durationMs,
      saving: saving ?? this.saving,
      saveError: clearSaveError ? null : (saveError ?? this.saveError),
    );
  }
}

/// `autoDispose`: the notifier (and the `engine.stop()` its `dispose()`
/// triggers) must tear down when the screen unmounts — otherwise a loop
/// test left running would keep audio playing in the background
/// indefinitely (spec.md's Edge Cases).
final trackAlignProvider = StateNotifierProvider.autoDispose
    .family<TrackAlignNotifier, TrackAlignState, String>(
  (ref, songId) => TrackAlignNotifier(ref, songId),
);

class TrackAlignNotifier extends StateNotifier<TrackAlignState> {
  TrackAlignNotifier(this._ref, this._songId)
      : _engine = _ref.read(audioPlaybackEngineProvider),
        super(const TrackAlignState.loading()) {
    _ref.listen<AsyncValue<Result<Song, Failure>>>(
      songByIdProvider(_songId),
      (previous, next) => _onSongResult(next),
      fireImmediately: true,
    );
  }

  final Ref _ref;
  final String _songId;
  final AudioPlaybackEngine _engine;
  StreamSubscription<int>? _positionSubscription;

  void _onSongResult(AsyncValue<Result<Song, Failure>> async) {
    async.when(
      loading: () => state = const TrackAlignState.loading(),
      error: (_, __) => state = state.copyWith(status: TrackAlignStatus.error),
      data: (result) => result.when(
        success: _onSongLoaded,
        failure: (failure) => state = state.copyWith(
          status: failure is NotFoundFailure
              ? TrackAlignStatus.notFound
              : TrackAlignStatus.error,
        ),
      ),
    );
  }

  Future<void> _onSongLoaded(Song song) async {
    if (song.tracks.isEmpty) {
      state = state.copyWith(status: TrackAlignStatus.noTracks, song: song);
      return;
    }

    final startDelayMsByTrackId = <String, int>{
      for (final track in song.tracks) track.id: track.startDelayMs,
    };
    final mutedByTrackId = <String, bool>{
      for (final track in song.tracks) track.id: false,
    };

    try {
      await _engine.loadSong(song);
    } catch (_) {
      state = state.copyWith(status: TrackAlignStatus.error, song: song);
      return;
    }

    state = state.copyWith(
      status: TrackAlignStatus.loaded,
      song: song,
      startDelayMsByTrackId: startDelayMsByTrackId,
      mutedByTrackId: mutedByTrackId,
      durationMs: _engine.durationMs,
      clearSaveError: true,
    );
  }

  /// Retries whichever step last failed: re-fetching the song (if it never
  /// loaded) or reloading the engine (if the song loaded but the engine
  /// didn't).
  void retry() {
    final song = state.song;
    if (song == null) {
      _ref.invalidate(songByIdProvider(_songId));
    } else {
      _onSongLoaded(song);
    }
  }

  Future<void> setOffset(String trackId, int startDelayMs) async {
    if (startDelayMs < 0) return;
    if (!state.startDelayMsByTrackId.containsKey(trackId)) return;

    state = state.copyWith(
      startDelayMsByTrackId: {
        ...state.startDelayMsByTrackId,
        trackId: startDelayMs,
      },
      hasUnsavedChanges: true,
    );
    await _engine.setTrackStartDelayMs(trackId, startDelayMs);
  }

  Future<void> setMuted(String trackId, bool muted) async {
    if (!state.mutedByTrackId.containsKey(trackId)) return;

    state = state.copyWith(
      mutedByTrackId: {...state.mutedByTrackId, trackId: muted},
    );
    await _engine.setTrackMuted(trackId, muted);
  }

  Future<void> setSolo(String trackId, bool solo) async {
    if (!state.mutedByTrackId.containsKey(trackId)) return;

    state = state.copyWith(
      soloTrackId: solo ? trackId : null,
      clearSolo: !solo && state.soloTrackId == trackId,
    );
    await _engine.setTrackSolo(trackId, solo);
  }

  void setLoopStart(int startMs) {
    if (startMs < 0) return;
    if (startMs >= state.loopEndMs) return;
    state = state.copyWith(loopStartMs: startMs);
  }

  void setLoopEnd(int endMs) {
    if (endMs <= state.loopStartMs) return;
    final durationMs = state.durationMs;
    if (durationMs != null && endMs > durationMs) return;
    state = state.copyWith(loopEndMs: endMs);
  }

  Future<void> toggleTest() async {
    if (state.testing) {
      await _stopTest();
      return;
    }

    final controller = LoopController(
      startMs: state.loopStartMs,
      endMs: state.loopEndMs,
      maxMs: state.durationMs ?? state.loopEndMs,
    );
    if (!controller.isValid) return;

    state = state.copyWith(testing: true);
    await _engine.seekAllTo(controller.startMs);
    await _engine.playAt(DateTime.now());
    _positionSubscription = _engine.positionMs.listen((positionMs) {
      if (controller.shouldReposition(positionMs)) {
        _engine.seekAllTo(controller.repositionTarget);
      }
    });
  }

  Future<void> _stopTest() async {
    // Deliberately not awaited: cancelling a subscription with no events
    // pending has nothing for the caller to wait on, and awaiting it here
    // has been observed to never resolve for some broadcast-stream
    // implementations under test (FakeAsync).
    _positionSubscription?.cancel();
    _positionSubscription = null;
    await _engine.stop();
    state = state.copyWith(testing: false);
  }

  Future<void> save() async {
    final song = state.song;
    if (song == null) return;

    state = state.copyWith(saving: true, clearSaveError: true);

    final updatedTracks = song.tracks
        .map((track) => SongTrack(
              id: track.id,
              filePath: track.filePath,
              naipe: track.naipe,
              startDelayMs: state.startDelayMsByTrackId[track.id] ?? track.startDelayMs,
              isPlayback: track.isPlayback,
            ))
        .toList();
    final updatedSong = Song(
      id: song.id,
      name: song.name,
      author: song.author,
      version: song.version,
      tracks: updatedTracks,
      lyrics: song.lyrics,
      metronomeConfig: song.metronomeConfig,
      playbackTrack: song.playbackTrack,
      origin: song.origin,
      lastRehearsedAt: song.lastRehearsedAt,
    );

    final repository = _ref.read(songRepositoryProvider);
    final result = await repository.save(updatedSong);
    result.when(
      success: (_) {
        _ref.invalidate(songsProvider);
        state = state.copyWith(
          song: updatedSong,
          saving: false,
          hasUnsavedChanges: false,
          clearSaveError: true,
        );
      },
      failure: (_) {
        state = state.copyWith(
          saving: false,
          saveError: 'Não foi possível salvar os atrasos.',
        );
      },
    );
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _engine.stop();
    super.dispose();
  }
}
