import 'dart:async';

import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

/// Test double for [JustAudioPlatform] — lets `AudioPlayer` (and therefore
/// `MultiTrackAudioEngine`) run under plain `flutter test` with no real
/// platform channel.
///
/// API verified against the installed `just_audio_platform_interface`
/// package source (pub cache `just_audio_platform_interface-4.6.0`) and
/// against `just_audio`'s own `AudioPlayer` internals (pub cache
/// `just_audio-0.9.46`): under `flutter test`, `AudioPlayer.setFilePath`
/// activates the native platform via `JustAudioPlatform.instance.init`, then
/// unconditionally calls `setVolume`/`setSpeed`/`setLoopMode`/`setShuffleMode`
/// on the returned [AudioPlayerPlatform] before `load` — those four must be
/// implemented or the load sequence throws `UnimplementedError`. `setPitch`/
/// `setSkipSilence` are called too but `just_audio` itself wraps them in
/// try/catch, so they're safe to leave unimplemented.
class FakeJustAudioPlatform extends JustAudioPlatform {
  final List<FakeAudioPlayerPlatform> created = [];

  /// Applied to every [FakeAudioPlayerPlatform] as it's created, so a test
  /// can configure the duration `load()` reports before calling code (like
  /// `MultiTrackAudioEngine.loadSong`) creates players it doesn't hold a
  /// direct reference to yet.
  Duration? defaultLoadDuration;

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    final player = FakeAudioPlayerPlatform(request.id)
      ..loadDuration = defaultLoadDuration;
    created.add(player);
    return player;
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(
    DisposePlayerRequest request,
  ) async {
    final player = created.where((p) => p.id == request.id);
    if (player.isNotEmpty) {
      player.first._disposed = true;
    }
    return DisposePlayerResponse();
  }
}

/// Per-instance fake for [AudioPlayerPlatform] — records every call so tests
/// can assert what `MultiTrackAudioEngine` actually did.
class FakeAudioPlayerPlatform extends AudioPlayerPlatform {
  FakeAudioPlayerPlatform(super.id);

  bool _disposed = false;
  bool get disposed => _disposed;

  /// Configured by the test before `load` resolves, mirroring the duration a
  /// real decoder would report.
  Duration? loadDuration;

  /// When true, `play` answers only once playback pauses (or the player is
  /// disposed), like the Android implementation (`AudioPlayer.java` keeps
  /// `playResult` until pause). `just_audio`'s `play()` documents the same
  /// contract: its future completes when playback pauses, stops or ends.
  bool holdPlayUntilPause = false;
  Completer<void>? _heldPlay;

  final StreamController<PlaybackEventMessage> _playbackEvents =
      StreamController<PlaybackEventMessage>.broadcast();

  final List<LoadRequest> loadCalls = [];
  final List<PlayRequest> playCalls = [];
  final List<PauseRequest> pauseCalls = [];
  final List<SetVolumeRequest> setVolumeCalls = [];
  final List<SeekRequest> seekCalls = [];
  final List<DisposeRequest> disposeCalls = [];

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream =>
      _playbackEvents.stream;

  /// Lets a test simulate a position/duration update without a real decoder.
  void emitPlaybackEvent(PlaybackEventMessage message) =>
      _playbackEvents.add(message);

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    loadCalls.add(request);
    // `AudioPlayer._load` blocks on the first non-"loading" processing-state
    // event from `playbackEventMessageStream` before it resolves — a real
    // platform implementation emits this itself once decoding starts. This
    // fake has no decoder, so it emits a synthetic "ready" event right away.
    _playbackEvents.add(PlaybackEventMessage(
      processingState: ProcessingStateMessage.ready,
      updateTime: DateTime.now(),
      updatePosition: Duration.zero,
      bufferedPosition: Duration.zero,
      duration: loadDuration,
      icyMetadata: null,
      currentIndex: 0,
      androidAudioSessionId: null,
    ));
    return LoadResponse(duration: loadDuration);
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    playCalls.add(request);
    if (holdPlayUntilPause) {
      final held = Completer<void>();
      _heldPlay = held;
      await held.future;
    }
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    pauseCalls.add(request);
    _releaseHeldPlay();
    return PauseResponse();
  }

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async {
    setVolumeCalls.add(request);
    return SetVolumeResponse();
  }

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async {
    return SetSpeedResponse();
  }

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async {
    return SetLoopModeResponse();
  }

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
    SetShuffleModeRequest request,
  ) async {
    return SetShuffleModeResponse();
  }

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    seekCalls.add(request);
    return SeekResponse();
  }

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    disposeCalls.add(request);
    _disposed = true;
    _releaseHeldPlay();
    return DisposeResponse();
  }

  void _releaseHeldPlay() {
    final held = _heldPlay;
    _heldPlay = null;
    if (held != null && !held.isCompleted) held.complete();
  }
}
