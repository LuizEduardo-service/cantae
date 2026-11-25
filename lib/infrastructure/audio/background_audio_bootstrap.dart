import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';

import '../../domain/audio/audio_interruptions.dart';
import '../../domain/audio/playback_remote.dart';
import 'audio_session_interruptions.dart';
import 'cantae_audio_handler.dart';

typedef BackgroundAudio = ({
  PlaybackRemote remote,
  AudioInterruptions interruptions,
});

/// Prepares background playback at app launch (background-audio BGA-01,
/// BGA-02, BGA-18): configures the audio session for music, registers the
/// single `audio_service` handler and opens the interruptions source.
///
/// Never throws: whatever fails falls back to its no-op, so the app still
/// opens and Modo solo still plays in the foreground.
///
/// SPEC_DEVIATION: design.md had this return Riverpod overrides. It returns
/// the two domain contracts instead and `main.dart` builds the overrides,
/// so infrastructure does not import presentation providers (AD-001).
Future<BackgroundAudio> bootstrapBackgroundAudio({
  Future<void> Function()? configureSession,
  Future<PlaybackRemote> Function()? startService,
  Future<AudioInterruptions> Function()? interruptions,
}) async {
  try {
    await (configureSession ?? _configureSession)();
  } catch (_) {
    // Plays with the platform's default session (design Error Handling).
  }

  PlaybackRemote remote = const NoPlaybackRemote();
  try {
    remote = await (startService ?? _startService)();
  } catch (_) {
    // No lock-screen controls; the app still plays in the foreground.
  }

  AudioInterruptions source = const NoAudioInterruptions();
  try {
    source = await (interruptions ?? _interruptions)();
  } catch (_) {
    // No interruption handling beyond the OS's own.
  }

  return (remote: remote, interruptions: source);
}

Future<void> _configureSession() async {
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());
}

Future<PlaybackRemote> _startService() => AudioService.init<CantaeAudioHandler>(
      builder: CantaeAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.cantae.cantae.playback',
        androidNotificationChannelName: 'Reprodução',
      ),
    );

Future<AudioInterruptions> _interruptions() async =>
    AudioSessionInterruptions.fromSession(await AudioSession.instance);
