import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';

import 'package:cantae/domain/core/failures.dart';

import '../../data/playback/playback_command_broadcaster.dart';
import 'multi_track_audio_engine.dart';

/// `audio_service`'s `BaseAudioHandler` implementation exposing one logical
/// "song" MediaItem to the OS lock screen / notification tray (design.md's
/// `BackgroundAudioHandler`, BG-01, BG-02, BG-03, BG-04).
///
/// [play]/[pause]/[stop] delegate to [PlaybackCommandBroadcaster] — never
/// directly to [MultiTrackAudioEngine] — so a background/lock-screen tap goes
/// through the exact same role-gated, latency-compensated broadcast path as
/// an in-app tap (BG-03: a visitor-role device's background tap is rejected
/// by the same envelope gate as an in-app one, with no separate check here).
///
/// On an OS audio-focus loss (another app takes focus), [_handleInterruption]
/// pauses [MultiTrackAudioEngine] locally only — no room-wide broadcast — and
/// surfaces a [PlaybackFailure] via [focusLostFailures], per BG-04 and
/// design.md's Error Handling Strategy ("does not corrupt the room's shared
/// playback state for other participants").
///
/// API verified against the installed `audio_service` package source
/// (pub cache `audio_service-0.18.19`, satisfying `pubspec.yaml`'s
/// `^0.18.13`): `BaseAudioHandler` overrides `play()`/`pause()`/`stop()`
/// returning `Future<void>`, matching design.md's sketch exactly.
///
/// SPEC_DEVIATION: design.md says this handler catches "`just_audio`'s audio
/// interruption callback", but `just_audio` has no interruption stream of
/// its own — interruptions are reported by the `audio_session` package,
/// which `just_audio` depends on internally (confirmed via its `play()`
/// implementation activating `AudioSession.instance`). `audio_session`
/// resolves as an already-present *transitive* dependency (see
/// `pubspec.lock`) but is not declared directly in `pubspec.yaml`; adding it
/// there is outside this task's `Where` field, so this file imports it
/// directly against the transitive resolution. No behavior-level deviation:
/// this is the only API surface that can report OS-level focus loss.
class BackgroundAudioHandler extends BaseAudioHandler {
  final PlaybackCommandBroadcaster _broadcaster;
  final MultiTrackAudioEngine _engine;
  final _focusLostController = StreamController<PlaybackFailure>.broadcast();
  StreamSubscription<AudioInterruptionEvent>? _interruptionSubscription;

  BackgroundAudioHandler({
    required PlaybackCommandBroadcaster broadcaster,
    required MultiTrackAudioEngine engine,
  })  : _broadcaster = broadcaster,
        _engine = engine {
    unawaited(_listenForInterruptions());
  }

  /// Surfaces a [PlaybackFailure] each time the OS reclaims audio focus
  /// mid-song (BG-04), after this handler has already paused [_engine]
  /// locally.
  Stream<PlaybackFailure> get focusLostFailures => _focusLostController.stream;

  Future<void> _listenForInterruptions() async {
    final session = await AudioSession.instance;
    _interruptionSubscription =
        session.interruptionEventStream.listen(_handleInterruption);
  }

  Future<void> _handleInterruption(AudioInterruptionEvent event) async {
    if (!event.begin) return;
    await _engine.pause();
    _focusLostController.add(PlaybackFailure(code: 'audio.focus-lost'));
  }

  /// MediaItem for the one logical "song" currently loaded, exposed to the
  /// OS notification tray / lock screen. Cosmetic metadata (artwork, etc.)
  /// is out of scope per spec.md.
  void setActiveSongMediaItem(String songId, String title) {
    mediaItem.add(MediaItem(id: songId, title: title));
  }

  @override
  Future<void> play() => _broadcaster.play(mediaItem.value?.id ?? '');

  @override
  Future<void> pause() => _broadcaster.pause();

  @override
  Future<void> stop() => _broadcaster.stop();

  Future<void> dispose() async {
    await _interruptionSubscription?.cancel();
    await _focusLostController.close();
  }
}
