import 'package:just_audio/just_audio.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_just_audio_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FakeJustAudioPlatform', () {
    test('a real AudioPlayer can load/play/setVolume/seek/dispose under it',
        () async {
      final fake = FakeJustAudioPlatform();
      final player = AudioPlayer(
        handleAudioSessionActivation: false,
        handleInterruptions: false,
      );
      await _withFake(fake, () async {
        await player.setFilePath('/tmp/soprano.mp3');
        await player.setVolume(0.5);
        await player.seek(const Duration(seconds: 1));
        await player.play();
        await player.dispose();
      });

      expect(fake.created, hasLength(1));
      final platform = fake.created.single;
      expect(platform.loadCalls, hasLength(1));
      expect(platform.setVolumeCalls.last.volume, 0.5);
      expect(platform.seekCalls.single.position, const Duration(seconds: 1));
      expect(platform.playCalls, hasLength(1));
      expect(platform.disposed, isTrue);
    });

    test('init() returns a fresh instance per call, in creation order',
        () async {
      final fake = FakeJustAudioPlatform();

      final a = await fake.init(InitRequest(id: 'a'));
      final b = await fake.init(InitRequest(id: 'b'));

      expect(fake.created, [a, b]);
      expect(a.id, 'a');
      expect(b.id, 'b');
    });

    test('playbackEventMessageStream lets a test push events directly',
        () async {
      final platform = FakeAudioPlayerPlatform('x');
      final events = <PlaybackEventMessage>[];
      platform.playbackEventMessageStream.listen(events.add);

      platform.emitPlaybackEvent(PlaybackEventMessage(
        processingState: ProcessingStateMessage.ready,
        updateTime: DateTime.now(),
        updatePosition: const Duration(seconds: 2),
        bufferedPosition: const Duration(seconds: 2),
        duration: const Duration(seconds: 10),
        icyMetadata: null,
        currentIndex: 0,
        androidAudioSessionId: null,
      ));
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.single.updatePosition, const Duration(seconds: 2));
    });
  });
}

Future<void> _withFake(
  FakeJustAudioPlatform fake,
  Future<void> Function() body,
) async {
  JustAudioPlatform.instance = fake;
  await body();
}
