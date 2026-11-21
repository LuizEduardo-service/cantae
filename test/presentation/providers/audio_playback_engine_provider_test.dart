import 'package:cantae/infrastructure/audio/multi_track_audio_engine.dart';
import 'package:cantae/presentation/providers/audio_playback_engine_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('audioPlaybackEngineProvider', () {
    test('returns a MultiTrackAudioEngine instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final engine = container.read(audioPlaybackEngineProvider);

      expect(engine, isA<MultiTrackAudioEngine>());
    });

    test('disposing the container disposes the engine without throwing',
        () async {
      final container = ProviderContainer();
      container.read(audioPlaybackEngineProvider);

      expect(container.dispose, returnsNormally);
    });
  });
}
