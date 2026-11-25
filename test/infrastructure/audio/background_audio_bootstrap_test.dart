import 'dart:async';

import 'package:cantae/domain/audio/audio_interruptions.dart';
import 'package:cantae/domain/audio/playback_remote.dart';
import 'package:cantae/infrastructure/audio/background_audio_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';

// Failure modes (BGA-01, BGA-02, BGA-18):
// - the audio service fails to start and the exception escapes main, so the
//   app never opens;
// - a session configuration error skips the service start;
// - the service starts before the session is configured (iOS would start
//   in the wrong category);
// - an interruptions error escapes or leaves no source at all.
class _Remote implements PlaybackRemote {
  @override
  void publish(NowPlaying info) {}

  @override
  void clear() {}

  @override
  Stream<RemoteCommand> get commands => const Stream.empty();
}

class _Interruptions implements AudioInterruptions {
  @override
  Stream<AudioInterruption> get events => const Stream.empty();
}

void main() {
  test(
      'everything starts: returns the service and the interruptions, '
      'configuring the session first', () async {
    final order = <String>[];
    final remote = _Remote();
    final interruptions = _Interruptions();

    final audio = await bootstrapBackgroundAudio(
      configureSession: () async => order.add('session'),
      startService: () async {
        order.add('service');
        return remote;
      },
      interruptions: () async {
        order.add('interruptions');
        return interruptions;
      },
    );

    expect(audio.remote, same(remote));
    expect(audio.interruptions, same(interruptions));
    expect(order.first, 'session');
    expect(order, containsAll(['service', 'interruptions']));
  });

  test('the service fails: the app still starts, with no remote', () async {
    final audio = await bootstrapBackgroundAudio(
      configureSession: () async {},
      startService: () async => throw StateError('no FlutterEngine'),
      interruptions: () async => _Interruptions(),
    );

    expect(audio.remote, isA<NoPlaybackRemote>());
    expect(audio.interruptions, isA<_Interruptions>());
  });

  test('the session fails: the service is still started', () async {
    final remote = _Remote();

    final audio = await bootstrapBackgroundAudio(
      configureSession: () async => throw StateError('session'),
      startService: () async => remote,
      interruptions: () async => _Interruptions(),
    );

    expect(audio.remote, same(remote));
  });

  test('the interruptions source fails: no interruptions, service kept',
      () async {
    final remote = _Remote();

    final audio = await bootstrapBackgroundAudio(
      configureSession: () async {},
      startService: () async => remote,
      interruptions: () async => throw StateError('interruptions'),
    );

    expect(audio.interruptions, isA<NoAudioInterruptions>());
    expect(audio.remote, same(remote));
  });
}
