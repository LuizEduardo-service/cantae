import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/audio/audio_playback_engine.dart';
import '../../domain/core/failures.dart';
import '../../domain/core/result.dart';
import '../../domain/entities/lyric_line.dart';
import '../../domain/entities/naipe.dart';
import '../../domain/entities/song.dart';
import 'audio_playback_engine_provider.dart';
import 'library_providers.dart';
import 'song_detail_providers.dart';
import 'song_repository_provider.dart';

enum LyricsEditorStatus { loading, notFound, error, loaded }

const int lyricTextMaxLength = 200;
const int lyricDynamicsMaxLength = 40;

/// A line being edited. Unlike [LyricLine], its text may be empty: a line
/// just added with "+ Acrescentar linha" has no text yet, and [LyricLine]
/// rejects empty text. Drafts still empty at save time are not persisted.
class LyricDraftLine {
  const LyricDraftLine({
    required this.text,
    this.onsetMs,
    this.naipe,
    this.dynamics,
  });

  factory LyricDraftLine.fromLyricLine(LyricLine line) => LyricDraftLine(
        text: line.text,
        onsetMs: line.onsetMs,
        naipe: line.naipe,
        dynamics: line.dynamics,
      );

  final String text;
  final int? onsetMs;
  final Naipe? naipe;
  final String? dynamics;

  bool get hasText => text.isNotEmpty;

  /// Only valid when [hasText] is true.
  LyricLine toLyricLine() => LyricLine(
        text: text,
        onsetMs: onsetMs,
        naipe: naipe,
        dynamics: dynamics,
      );

  LyricDraftLine copyWith({
    String? text,
    int? onsetMs,
    Naipe? naipe,
    bool clearNaipe = false,
    String? dynamics,
    bool clearDynamics = false,
  }) {
    return LyricDraftLine(
      text: text ?? this.text,
      onsetMs: onsetMs ?? this.onsetMs,
      naipe: clearNaipe ? null : (naipe ?? this.naipe),
      dynamics: clearDynamics ? null : (dynamics ?? this.dynamics),
    );
  }
}

/// State for `lyrics-editor` — see `design.md`'s `LyricsEditorNotifier`.
///
/// [previewing] is marking mode (footer visible); [playing] is whether audio
/// runs inside it. Pausing keeps [previewing] true (spec AC9).
class LyricsEditorState {
  const LyricsEditorState({
    required this.status,
    this.song,
    this.lines = const [],
    this.expandedIndex,
    this.previewing = false,
    this.playing = false,
    this.currentPositionMs = 0,
    this.markError,
    this.previewError,
    this.hasUnsavedChanges = false,
    this.saving = false,
    this.saveError,
  });

  const LyricsEditorState.loading() : this(status: LyricsEditorStatus.loading);

  final LyricsEditorStatus status;
  final Song? song;
  final List<LyricDraftLine> lines;
  final int? expandedIndex;
  final bool previewing;
  final bool playing;
  final int currentPositionMs;
  final String? markError;
  final String? previewError;
  final bool hasUnsavedChanges;
  final bool saving;
  final String? saveError;

  int get markedCount => lines.where((l) => l.onsetMs != null).length;

  int? get nextUnmarkedIndex {
    final index = lines.indexWhere((l) => l.onsetMs == null);
    return index == -1 ? null : index;
  }

  /// The marked line with the greatest onset at or before
  /// [currentPositionMs], or null when none has started yet (spec AC14).
  int? get currentLineIndex {
    int? bestIndex;
    var bestOnset = -1;
    for (var i = 0; i < lines.length; i++) {
      final onset = lines[i].onsetMs;
      if (onset == null || onset > currentPositionMs) continue;
      if (onset > bestOnset) {
        bestOnset = onset;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  LyricsEditorState copyWith({
    LyricsEditorStatus? status,
    Song? song,
    List<LyricDraftLine>? lines,
    int? expandedIndex,
    bool clearExpanded = false,
    bool? previewing,
    bool? playing,
    int? currentPositionMs,
    String? markError,
    bool clearMarkError = false,
    String? previewError,
    bool clearPreviewError = false,
    bool? hasUnsavedChanges,
    bool? saving,
    String? saveError,
    bool clearSaveError = false,
  }) {
    return LyricsEditorState(
      status: status ?? this.status,
      song: song ?? this.song,
      lines: lines ?? this.lines,
      expandedIndex:
          clearExpanded ? null : (expandedIndex ?? this.expandedIndex),
      previewing: previewing ?? this.previewing,
      playing: playing ?? this.playing,
      currentPositionMs: currentPositionMs ?? this.currentPositionMs,
      markError: clearMarkError ? null : (markError ?? this.markError),
      previewError:
          clearPreviewError ? null : (previewError ?? this.previewError),
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      saving: saving ?? this.saving,
      saveError: clearSaveError ? null : (saveError ?? this.saveError),
    );
  }
}

/// `autoDispose`: `dispose()` must stop the preview when the screen
/// unmounts, so audio never keeps playing in the background (spec Edge
/// Cases, LYR-21).
final lyricsEditorProvider = StateNotifierProvider.autoDispose
    .family<LyricsEditorNotifier, LyricsEditorState, String>(
  (ref, songId) => LyricsEditorNotifier(ref, songId),
);

class LyricsEditorNotifier extends StateNotifier<LyricsEditorState> {
  LyricsEditorNotifier(this._ref, this._songId)
      : _engine = _ref.read(audioPlaybackEngineProvider),
        super(const LyricsEditorState.loading()) {
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
  bool _engineLoaded = false;

  void _onSongResult(AsyncValue<Result<Song, Failure>> async) {
    // While re-fetching (after save or retry), Riverpod still carries the
    // previous value. Applying it would briefly show stale lyrics, so keep
    // the current state until the fresh result arrives.
    if (async.isLoading) {
      if (!async.hasValue) state = const LyricsEditorState.loading();
      return;
    }
    async.when(
      loading: () => state = const LyricsEditorState.loading(),
      error: (_, __) =>
          state = state.copyWith(status: LyricsEditorStatus.error),
      data: (result) => result.when(
        success: _onSongLoaded,
        failure: (failure) => state = state.copyWith(
          status: failure is NotFoundFailure
              ? LyricsEditorStatus.notFound
              : LyricsEditorStatus.error,
        ),
      ),
    );
  }

  void _onSongLoaded(Song song) {
    state = state.copyWith(
      status: LyricsEditorStatus.loaded,
      song: song,
      lines: song.lyrics.map(LyricDraftLine.fromLyricLine).toList(),
      hasUnsavedChanges: false,
      clearSaveError: true,
    );
  }

  void retry() => _ref.invalidate(songByIdProvider(_songId));

  void addLine() {
    final lines = [...state.lines, const LyricDraftLine(text: '')];
    state = state.copyWith(
      lines: lines,
      expandedIndex: lines.length - 1,
      hasUnsavedChanges: true,
    );
  }

  void updateText(int index, String text) {
    if (text.isEmpty || text.length > lyricTextMaxLength) return;
    _replaceLine(index, (line) => line.copyWith(text: text));
  }

  void updateNaipe(int index, Naipe? naipe) {
    _replaceLine(
      index,
      (line) => line.copyWith(naipe: naipe, clearNaipe: naipe == null),
    );
  }

  /// An empty value clears the dinâmica (spec P2 AC5: it is optional).
  void updateDynamics(int index, String? dynamics) {
    final value = (dynamics == null || dynamics.isEmpty) ? null : dynamics;
    if (value != null && value.length > lyricDynamicsMaxLength) return;
    _replaceLine(
      index,
      (line) => line.copyWith(dynamics: value, clearDynamics: value == null),
    );
  }

  void setExpanded(int? index) {
    state = state.copyWith(expandedIndex: index, clearExpanded: index == null);
  }

  void _replaceLine(
    int index,
    LyricDraftLine Function(LyricDraftLine line) change,
  ) {
    if (index < 0 || index >= state.lines.length) return;
    final lines = [...state.lines];
    lines[index] = change(lines[index]);
    state = state.copyWith(lines: lines, hasUnsavedChanges: true);
  }

  /// Turns marking mode on (from 0 ms) or off.
  Future<void> togglePreview() async {
    if (state.previewing) {
      await _stopPreview();
      return;
    }

    final song = state.song;
    if (song == null || song.tracks.isEmpty) return;

    if (!_engineLoaded) {
      try {
        await _engine.loadSong(song);
        _engineLoaded = true;
      } catch (_) {
        state = state.copyWith(
          previewError: 'Não foi possível tocar as faixas desta música.',
        );
        return;
      }
    }

    await _engine.seekAllTo(0);
    await _engine.playAt(DateTime.now());
    _positionSubscription = _engine.positionMs.listen((positionMs) {
      state = state.copyWith(currentPositionMs: positionMs);
    });
    state = state.copyWith(
      previewing: true,
      playing: true,
      currentPositionMs: 0,
      clearMarkError: true,
      clearPreviewError: true,
    );
  }

  /// "Pausar" / "Continuar" inside marking mode. Resuming does not seek, so
  /// audio continues where it paused (spec AC9).
  Future<void> togglePause() async {
    if (!state.previewing) return;
    if (state.playing) {
      await _engine.pause();
      state = state.copyWith(playing: false);
    } else {
      await _engine.playAt(DateTime.now());
      state = state.copyWith(playing: true);
    }
  }

  Future<void> _stopPreview() async {
    // Deliberately not awaited: same never-resolving cancel() under
    // FakeAsync already seen in TrackAlignNotifier._stopTest.
    _positionSubscription?.cancel();
    _positionSubscription = null;
    await _engine.stop();
    state = state.copyWith(previewing: false, playing: false);
  }

  void markNow() {
    if (!state.playing) return;
    final index = state.nextUnmarkedIndex;
    if (index == null) return;

    final now = state.currentPositionMs;
    final previousOnset = _previousMarkedOnset(index);
    if (previousOnset != null && now < previousOnset) {
      state = state.copyWith(
        markError: 'Esse momento vem antes da linha anterior.',
      );
      return;
    }

    final lines = [...state.lines];
    lines[index] = lines[index].copyWith(onsetMs: now);
    state = state.copyWith(
      lines: lines,
      hasUnsavedChanges: true,
      clearMarkError: true,
    );
  }

  int? _previousMarkedOnset(int index) {
    for (var i = index - 1; i >= 0; i--) {
      final onset = state.lines[i].onsetMs;
      if (onset != null) return onset;
    }
    return null;
  }

  Future<void> save() async {
    final song = state.song;
    if (song == null) return;

    state = state.copyWith(saving: true, clearSaveError: true);

    final updatedSong = Song(
      id: song.id,
      name: song.name,
      author: song.author,
      version: song.version,
      tracks: song.tracks,
      lyrics: state.lines
          .where((line) => line.hasText)
          .map((line) => line.toLyricLine())
          .toList(),
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
        // Re-fetch so the screen shows what was stored (empty drafts gone).
        _ref.invalidate(songByIdProvider(_songId));
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
          saveError: 'Não foi possível salvar a letra.',
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
