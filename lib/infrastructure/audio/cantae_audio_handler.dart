import 'dart:async';

import 'package:audio_service/audio_service.dart';

import '../../domain/audio/playback_remote.dart';

/// The app's single `audio_service` handler (background-audio design).
///
/// It does not play anything itself: it shows what the active screen
/// publishes and turns lock-screen / notification taps into
/// [RemoteCommand]s, which the screen runs through its own play, pause and
/// seek paths (BGA-07/08).
class CantaeAudioHandler extends BaseAudioHandler implements PlaybackRemote {
  final _commands = StreamController<RemoteCommand>.broadcast();

  @override
  Stream<RemoteCommand> get commands => _commands.stream;

  @override
  void publish(NowPlaying info) {
    mediaItem.add(MediaItem(
      id: 'solo',
      title: info.title,
      artist: info.subtitle,
      duration: Duration(milliseconds: info.durationMs),
    ));
    // Only Tocar/Pausar and the seek bar (BGA-09). The position is sent on
    // discrete events; the OS extrapolates it while playing.
    playbackState.add(PlaybackState(
      controls: [info.playing ? MediaControl.pause : MediaControl.play],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0],
      processingState: AudioProcessingState.ready,
      playing: info.playing,
      updatePosition: Duration(milliseconds: info.positionMs),
    ));
  }

  @override
  void clear() {
    mediaItem.add(null);
    playbackState.add(PlaybackState());
  }

  @override
  Future<void> play() async => _commands.add(const RemotePlay());

  @override
  Future<void> pause() async => _commands.add(const RemotePause());

  @override
  Future<void> seek(Duration position) async =>
      _commands.add(RemoteSeek(position.inMilliseconds));

  @override
  Future<void> stop() async => _commands.add(const RemoteStop());

  @override
  Future<void> onTaskRemoved() async => _commands.add(const RemoteStop());
}
