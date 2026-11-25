import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/audio/audio_playback_engine.dart';
import '../../domain/audio/click_track_builder.dart';
import '../../domain/audio/loop_controller.dart';
import '../../domain/core/failures.dart';
import '../../domain/core/result.dart';
import '../../domain/entities/metronome_config.dart';
import '../../domain/entities/naipe.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/song_origin.dart';
import '../../domain/entities/song_track.dart';
import 'audio_playback_engine_provider.dart';
import 'click_track_builder_provider.dart';
import 'library_providers.dart';
import 'song_detail_providers.dart';
import 'song_repository_provider.dart';

enum SoloPlayerStatus { loading, notFound, error, noTracks, audioError, ready }

const String loopEndBeforeStartMessage =
    'O fim do trecho precisa vir depois do início.';
const String metronomeFailedMessage = 'Não foi possível preparar o metrônomo.';
const String tempoSaveFailedMessage = 'Não foi possível salvar o andamento.';

/// Engine track id of the metronome's click track.
const String metronomeTrackId = 'metronome';

/// One track's session-only mix (spec P2-AC7: never persisted).
class TrackMix {
  const TrackMix({this.volume = 1.0, this.muted = false});

  /// 0.0..1.0.
  final double volume;
  final bool muted;

  TrackMix copyWith({double? volume, bool? muted}) => TrackMix(
        volume: volume ?? this.volume,
        muted: muted ?? this.muted,
      );
}

/// State for `solo-player` — see `design.md`'s `SoloPlayerNotifier`.
class SoloPlayerState {
  const SoloPlayerState({
    required this.status,
    this.song,
    this.durationMs = 0,
    this.positionMs = 0,
    this.playing = false,
    this.ended = false,
    this.mix = const {},
    this.soloTrackId,
    this.loopStartMs,
    this.loop,
    this.loopError,
    this.metronomeOn = false,
    this.metronomeVolume = 1.0,
    this.metronomeMuted = false,
    this.metronomeBusy = false,
    this.metronomeError,
    this.tempoSaveError,
  });

  const SoloPlayerState.loading() : this(status: SoloPlayerStatus.loading);

  final SoloPlayerStatus status;
  final Song? song;
  final int durationMs;
  final int positionMs;
  final bool playing;

  /// Playback reached the end; the next play restarts from 0 (spec P1-AC7).
  final bool ended;

  /// Keyed by track id, one entry per [mixTracks] entry.
  final Map<String, TrackMix> mix;
  final String? soloTrackId;

  /// Loop start marked, end still pending.
  final int? loopStartMs;

  /// The active loop, or null when there is none.
  final LoopController? loop;
  final String? loopError;

  /// The click track is loaded in the engine.
  final bool metronomeOn;

  /// Session-only click mix (spec P4-AC4).
  final double metronomeVolume;
  final bool metronomeMuted;

  /// Preparing the click track.
  final bool metronomeBusy;
  final String? metronomeError;
  final String? tempoSaveError;

  MetronomeConfig? get metronomeConfig => song?.metronomeConfig;

  /// A song received from a room is read-only (spec P3-AC6/AC7).
  bool get canEditTempo => song?.origin == SongOrigin.created;

  /// Every track the engine loads, in its load order: the naipe tracks,
  /// then the Playback track.
  List<SongTrack> get mixTracks {
    final song = this.song;
    if (song == null) return const [];
    return [
      ...song.tracks,
      if (song.playbackTrack != null) song.playbackTrack!,
    ];
  }

  bool get canMarkLoop => playing && loop == null;

  SoloPlayerState copyWith({
    SoloPlayerStatus? status,
    Song? song,
    int? durationMs,
    int? positionMs,
    bool? playing,
    bool? ended,
    Map<String, TrackMix>? mix,
    String? soloTrackId,
    bool clearSolo = false,
    int? loopStartMs,
    bool clearLoopStart = false,
    LoopController? loop,
    bool clearLoop = false,
    String? loopError,
    bool clearLoopError = false,
    bool? metronomeOn,
    double? metronomeVolume,
    bool? metronomeMuted,
    bool? metronomeBusy,
    String? metronomeError,
    bool clearMetronomeError = false,
    String? tempoSaveError,
    bool clearTempoSaveError = false,
  }) {
    return SoloPlayerState(
      status: status ?? this.status,
      song: song ?? this.song,
      durationMs: durationMs ?? this.durationMs,
      positionMs: positionMs ?? this.positionMs,
      playing: playing ?? this.playing,
      ended: ended ?? this.ended,
      mix: mix ?? this.mix,
      soloTrackId: clearSolo ? null : (soloTrackId ?? this.soloTrackId),
      loopStartMs: clearLoopStart ? null : (loopStartMs ?? this.loopStartMs),
      loop: clearLoop ? null : (loop ?? this.loop),
      loopError: clearLoopError ? null : (loopError ?? this.loopError),
      metronomeOn: metronomeOn ?? this.metronomeOn,
      metronomeVolume: metronomeVolume ?? this.metronomeVolume,
      metronomeMuted: metronomeMuted ?? this.metronomeMuted,
      metronomeBusy: metronomeBusy ?? this.metronomeBusy,
      metronomeError:
          clearMetronomeError ? null : (metronomeError ?? this.metronomeError),
      tempoSaveError:
          clearTempoSaveError ? null : (tempoSaveError ?? this.tempoSaveError),
    );
  }
}

/// `autoDispose`: `dispose()` must stop the audio when the screen unmounts
/// (spec P1-AC8, SOLO-07).
final soloPlayerProvider = StateNotifierProvider.autoDispose
    .family<SoloPlayerNotifier, SoloPlayerState, String>(
  (ref, songId) => SoloPlayerNotifier(ref, songId),
);

class SoloPlayerNotifier extends StateNotifier<SoloPlayerState> {
  SoloPlayerNotifier(this._ref, this._songId)
      : _engine = _ref.read(audioPlaybackEngineProvider),
        _clickTrackBuilder = _ref.read(clickTrackBuilderProvider),
        super(const SoloPlayerState.loading()) {
    _ref.listen<AsyncValue<Result<Song, Failure>>>(
      songByIdProvider(_songId),
      (previous, next) => _onSongResult(next),
      fireImmediately: true,
    );
  }

  final Ref _ref;
  final String _songId;
  final AudioPlaybackEngine _engine;
  final ClickTrackBuilder _clickTrackBuilder;
  StreamSubscription<int>? _positionSubscription;

  void _onSongResult(AsyncValue<Result<Song, Failure>> async) {
    // While re-fetching, Riverpod still carries the previous value; keep the
    // current state until the fresh result arrives (lyrics-editor 2ba116c).
    if (async.isLoading) {
      if (!async.hasValue) state = const SoloPlayerState.loading();
      return;
    }
    async.when(
      loading: () => state = const SoloPlayerState.loading(),
      error: (_, __) => state = state.copyWith(status: SoloPlayerStatus.error),
      data: (result) => result.when(
        success: _onSongLoaded,
        failure: (failure) => state = state.copyWith(
          status: failure is NotFoundFailure
              ? SoloPlayerStatus.notFound
              : SoloPlayerStatus.error,
        ),
      ),
    );
  }

  void _onSongLoaded(Song song) {
    if (state.status == SoloPlayerStatus.ready) {
      state = state.copyWith(song: song);
      return;
    }
    state = state.copyWith(song: song);
    if (state.mixTracks.isEmpty) {
      state = state.copyWith(status: SoloPlayerStatus.noTracks);
      return;
    }
    _loadAudio();
  }

  Future<void> _loadAudio() async {
    final song = state.song;
    if (song == null) return;
    state = state.copyWith(status: SoloPlayerStatus.loading);
    try {
      await _engine.loadSong(song);
    } catch (_) {
      // Missing or unreadable file: an infrastructure exception, mapped to
      // a screen state here (spec Edge Cases, SOLO-25).
      if (mounted) state = state.copyWith(status: SoloPlayerStatus.audioError);
      return;
    }
    if (!mounted) return;
    _positionSubscription ??= _engine.positionMs.listen(_onPosition);
    state = state.copyWith(
      status: SoloPlayerStatus.ready,
      durationMs: _engine.durationMs ?? 0,
      positionMs: 0,
      playing: false,
      ended: false,
      mix: {for (final track in state.mixTracks) track.id: const TrackMix()},
      clearSolo: true,
      clearLoopStart: true,
      clearLoop: true,
      clearLoopError: true,
      metronomeOn: false,
      metronomeBusy: false,
      clearMetronomeError: true,
    );
    if (state.metronomeConfig?.enabledByDefault ?? false) {
      await _turnMetronomeOn();
    }
  }

  void _onPosition(int positionMs) {
    final loop = state.loop;
    if (loop != null && loop.shouldReposition(positionMs)) {
      state = state.copyWith(positionMs: loop.repositionTarget);
      _engine.seekAllTo(loop.repositionTarget);
      return;
    }
    final durationMs = state.durationMs;
    if (state.playing && durationMs > 0 && positionMs >= durationMs) {
      state = state.copyWith(
        playing: false,
        ended: true,
        positionMs: durationMs,
      );
      _engine.pause();
      return;
    }
    state = state.copyWith(positionMs: positionMs);
  }

  void retry() {
    if (state.status == SoloPlayerStatus.audioError) {
      _loadAudio();
      return;
    }
    _ref.invalidate(songByIdProvider(_songId));
  }

  /// State flips before awaiting the engine, so quick repeated taps end in
  /// the state of the last tap (spec Edge Cases).
  Future<void> togglePlay() async {
    if (state.status != SoloPlayerStatus.ready) return;
    if (state.playing) {
      state = state.copyWith(playing: false);
      await _engine.pause();
      return;
    }
    final restart = state.ended;
    state = state.copyWith(
      playing: true,
      ended: false,
      positionMs: restart ? 0 : null,
    );
    if (restart) await _engine.seekAllTo(0);
    await _engine.playAt(DateTime.now());
  }

  Future<void> seekTo(int ms) async {
    if (state.status != SoloPlayerStatus.ready) return;
    final target = ms.clamp(0, state.durationMs);
    state = state.copyWith(positionMs: target, ended: false);
    await _engine.seekAllTo(target);
  }

  Future<void> setVolume(String trackId, double volume) async {
    final current = state.mix[trackId];
    if (current == null) return;
    final clamped = volume.clamp(0.0, 1.0);
    state = state.copyWith(
      mix: {...state.mix, trackId: current.copyWith(volume: clamped)},
    );
    await _engine.setTrackVolume(trackId, clamped);
  }

  Future<void> toggleMute(String trackId) async {
    final current = state.mix[trackId];
    if (current == null) return;
    final muted = !current.muted;
    state = state.copyWith(
      mix: {...state.mix, trackId: current.copyWith(muted: muted)},
    );
    await _engine.setTrackMuted(trackId, muted);
  }

  Future<void> toggleSolo(String trackId) async {
    if (!state.mix.containsKey(trackId)) return;
    final undo = state.soloTrackId == trackId;
    state = state.copyWith(soloTrackId: trackId, clearSolo: undo);
    await _engine.setTrackSolo(trackId, !undo);
  }

  void markLoopStart() {
    if (!state.canMarkLoop || state.loopStartMs != null) return;
    state = state.copyWith(
      loopStartMs: state.positionMs,
      clearLoopError: true,
    );
  }

  void markLoopEnd() {
    final startMs = state.loopStartMs;
    if (!state.playing || startMs == null) return;
    final loop = LoopController(
      startMs: startMs,
      endMs: state.positionMs,
      maxMs: state.durationMs,
    );
    if (!loop.isValid) {
      state = state.copyWith(loopError: loopEndBeforeStartMessage);
      return;
    }
    state = state.copyWith(
      loop: loop,
      clearLoopStart: true,
      clearLoopError: true,
    );
  }

  /// Turns the loop off and keeps playing from the current position, with
  /// no jump (RF10).
  void clearLoop() {
    state = state.copyWith(
      clearLoop: true,
      clearLoopStart: true,
      clearLoopError: true,
    );
  }

  /// Turns the metronome on (with a tempo) or off. Off removes only the
  /// click track: the voices keep playing (spec P2-AC3).
  Future<void> toggleMetronome() async {
    if (state.status != SoloPlayerStatus.ready || state.metronomeBusy) return;
    if (state.metronomeOn) {
      state = state.copyWith(metronomeOn: false);
      await _engine.removeTrack(metronomeTrackId);
      return;
    }
    await _turnMetronomeOn();
  }

  Future<void> _turnMetronomeOn() async {
    final config = state.metronomeConfig;
    if (config == null) return;
    state = state.copyWith(metronomeBusy: true, clearMetronomeError: true);

    final result = await _clickTrackBuilder.build(
      songId: _songId,
      config: config,
      durationMs: state.durationMs,
    );
    if (!mounted) return;
    final path = result.when(success: (path) => path, failure: (_) => null);
    if (path == null) {
      _metronomeFailed();
      return;
    }

    // The click must start aligned to the voices (spec Edge Cases): stop,
    // add it, move everything to the current position, then resume.
    final wasPlaying = state.playing;
    try {
      if (wasPlaying) await _engine.pause();
      await _engine.addTrack(
        SongTrack(id: metronomeTrackId, filePath: path, naipe: Naipe.custom),
        exemptFromSolo: true,
      );
      await _engine.setTrackVolume(metronomeTrackId, state.metronomeVolume);
      if (state.metronomeMuted) {
        await _engine.setTrackMuted(metronomeTrackId, true);
      }
      await _engine.seekAllTo(state.positionMs);
    } catch (_) {
      // Unreadable click file: an infrastructure exception, mapped to the
      // same message; the music resumes (spec P2-AC7).
      if (wasPlaying) await _engine.playAt(DateTime.now());
      if (mounted) _metronomeFailed();
      return;
    }
    if (wasPlaying) await _engine.playAt(DateTime.now());
    if (!mounted) return;
    state = state.copyWith(metronomeOn: true, metronomeBusy: false);
  }

  void _metronomeFailed() {
    state = state.copyWith(
      metronomeOn: false,
      metronomeBusy: false,
      metronomeError: metronomeFailedMessage,
    );
  }

  /// Saves the tempo to the song (RF50) and turns the metronome on with it.
  /// Returns false on failure or for a received song.
  Future<bool> saveTempo(MetronomeConfig config) async {
    final song = state.song;
    if (song == null || !state.canEditTempo) return false;

    final updated = Song(
      id: song.id,
      name: song.name,
      author: song.author,
      version: song.version,
      tracks: song.tracks,
      lyrics: song.lyrics,
      metronomeConfig: MetronomeConfig(
        bpm: config.bpm,
        beatsPerMeasure: config.beatsPerMeasure,
        downbeatAccent: config.downbeatAccent,
        enabledByDefault: song.metronomeConfig?.enabledByDefault ?? false,
      ),
      playbackTrack: song.playbackTrack,
      origin: song.origin,
      lastRehearsedAt: song.lastRehearsedAt,
    );
    state = state.copyWith(clearTempoSaveError: true);

    final result = await _ref.read(songRepositoryProvider).save(updated);
    if (!mounted) return false;
    if (!result.isSuccess) {
      state = state.copyWith(tempoSaveError: tempoSaveFailedMessage);
      return false;
    }

    state = state.copyWith(song: updated);
    _ref.invalidate(songsProvider);
    _ref.invalidate(songByIdProvider(_songId));
    if (state.metronomeOn) {
      state = state.copyWith(metronomeOn: false);
      await _engine.removeTrack(metronomeTrackId);
    }
    await _turnMetronomeOn();
    return true;
  }

  Future<void> setMetronomeVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    state = state.copyWith(metronomeVolume: clamped);
    if (state.metronomeOn) {
      await _engine.setTrackVolume(metronomeTrackId, clamped);
    }
  }

  Future<void> toggleMetronomeMute() async {
    final muted = !state.metronomeMuted;
    state = state.copyWith(metronomeMuted: muted);
    if (state.metronomeOn) {
      await _engine.setTrackMuted(metronomeTrackId, muted);
    }
  }

  @override
  void dispose() {
    // Not awaited: same never-resolving cancel() under FakeAsync seen in
    // TrackAlignNotifier._stopTest.
    _positionSubscription?.cancel();
    _engine.stop();
    super.dispose();
  }
}
