import 'package:audio_service/audio_service.dart';
import 'package:cantae/domain/audio/playback_remote.dart';
import 'package:cantae/infrastructure/audio/cantae_audio_handler.dart';
import 'package:flutter_test/flutter_test.dart';

// Failure modes (BGA-05..BGA-10):
// - the lock screen shows a stale or empty title, or no duration (no bar);
// - the button shows "Tocar" while music plays (controls not flipped);
// - extra controls (next, stop, rewind) appear, or seek is missing so the
//   bar cannot be dragged;
// - the position shown jumps because updatePosition is not published;
// - clearing leaves the notification (mediaItem kept, state not idle);
// - an OS tap is dropped or mapped to the wrong command;
// - closing the app from recents keeps the music playing.
void main() {
  late CantaeAudioHandler handler;
  late List<RemoteCommand> commands;

  setUp(() {
    handler = CantaeAudioHandler();
    commands = [];
    handler.commands.listen(commands.add);
  });

  const playing = NowPlaying(
    title: 'Ave Maria',
    subtitle: 'Modo solo',
    durationMs: 180000,
    playing: true,
    positionMs: 41000,
  );

  group('publish', () {
    test('sets title, subtitle and duration on the media item', () {
      handler.publish(playing);

      final item = handler.mediaItem.value!;
      expect(item.title, 'Ave Maria');
      expect(item.artist, 'Modo solo');
      expect(item.duration, const Duration(milliseconds: 180000));
    });

    test('while playing: only Pausar, seekable, ready, at the position', () {
      handler.publish(playing);

      final state = handler.playbackState.value;
      expect(state.controls, [MediaControl.pause]);
      expect(state.systemActions, {MediaAction.seek});
      expect(state.androidCompactActionIndices, [0]);
      expect(state.processingState, AudioProcessingState.ready);
      expect(state.playing, isTrue);
      expect(state.updatePosition, const Duration(milliseconds: 41000));
    });

    test('while paused: only Tocar, not playing', () {
      handler.publish(const NowPlaying(
        title: 'Ave Maria',
        subtitle: 'Modo solo',
        durationMs: 180000,
        playing: false,
        positionMs: 0,
      ));

      final state = handler.playbackState.value;
      expect(state.controls, [MediaControl.play]);
      expect(state.systemActions, {MediaAction.seek});
      expect(state.playing, isFalse);
      expect(state.updatePosition, Duration.zero);
    });
  });

  test('clear removes the media item and goes idle', () {
    handler.publish(playing);

    handler.clear();

    expect(handler.mediaItem.value, isNull);
    final state = handler.playbackState.value;
    expect(state.processingState, AudioProcessingState.idle);
    expect(state.playing, isFalse);
    expect(state.controls, isEmpty);
  });

  group('OS callbacks become commands', () {
    test('play → RemotePlay', () async {
      await handler.play();
      await pumpEventQueue();
      expect(commands.single, isA<RemotePlay>());
    });

    test('pause → RemotePause', () async {
      await handler.pause();
      await pumpEventQueue();
      expect(commands.single, isA<RemotePause>());
    });

    test('seek → RemoteSeek with the position in ms', () async {
      await handler.seek(const Duration(milliseconds: 41500));
      await pumpEventQueue();
      expect((commands.single as RemoteSeek).positionMs, 41500);
    });

    test('stop → RemoteStop', () async {
      await handler.stop();
      await pumpEventQueue();
      expect(commands.single, isA<RemoteStop>());
    });

    test('closing the app from recents → RemoteStop', () async {
      await handler.onTaskRemoved();
      await pumpEventQueue();
      expect(commands.single, isA<RemoteStop>());
    });
  });

  test('NoPlaybackRemote accepts publish/clear and never commands', () async {
    const remote = NoPlaybackRemote();
    final received = <RemoteCommand>[];
    remote.commands.listen(received.add);

    remote.publish(playing);
    remote.clear();
    await pumpEventQueue();

    expect(received, isEmpty);
  });
}
