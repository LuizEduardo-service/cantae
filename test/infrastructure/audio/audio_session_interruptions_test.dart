import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:cantae/domain/audio/audio_interruptions.dart';
import 'package:cantae/infrastructure/audio/audio_session_interruptions.dart';
import 'package:flutter_test/flutter_test.dart';

// Failure modes (BGA-11/12/13):
// - a pause interruption is reported as a duck (music keeps playing over a
//   call) or a duck as a pause (a notification sound stops the rehearsal);
// - an "unknown" interruption (possibly permanent) is not treated as a pause;
// - the end of an "unknown" interruption is reported as pauseEnded, inviting
//   a resume nobody asked for;
// - headphones disconnecting is not reported, so music jumps to the speaker;
// - events keep flowing after dispose (leaked subscription).
void main() {
  late StreamController<AudioInterruptionEvent> interruptions;
  late StreamController<void> noisy;
  late AudioSessionInterruptions mapper;
  late List<AudioInterruption> received;

  setUp(() {
    interruptions = StreamController<AudioInterruptionEvent>.broadcast();
    noisy = StreamController<void>.broadcast();
    mapper = AudioSessionInterruptions(
      interruptions: interruptions.stream,
      becomingNoisy: noisy.stream,
    );
    received = [];
    mapper.events.listen(received.add);
  });

  tearDown(() async {
    await interruptions.close();
    await noisy.close();
  });

  Future<List<AudioInterruption>> emit(
    bool begin,
    AudioInterruptionType type,
  ) async {
    interruptions.add(AudioInterruptionEvent(begin, type));
    await pumpEventQueue();
    return received;
  }

  group('AudioSessionInterruptions', () {
    test('pause begins → pauseBegan', () async {
      expect(await emit(true, AudioInterruptionType.pause),
          [AudioInterruption.pauseBegan]);
    });

    test('unknown begins → pauseBegan', () async {
      expect(await emit(true, AudioInterruptionType.unknown),
          [AudioInterruption.pauseBegan]);
    });

    test('pause ends → pauseEnded', () async {
      expect(await emit(false, AudioInterruptionType.pause),
          [AudioInterruption.pauseEnded]);
    });

    test('unknown ends → nothing', () async {
      expect(await emit(false, AudioInterruptionType.unknown), isEmpty);
    });

    test('duck begins → duckBegan', () async {
      expect(await emit(true, AudioInterruptionType.duck),
          [AudioInterruption.duckBegan]);
    });

    test('duck ends → duckEnded', () async {
      expect(await emit(false, AudioInterruptionType.duck),
          [AudioInterruption.duckEnded]);
    });

    test('becoming noisy → headphonesDisconnected', () async {
      noisy.add(null);
      await pumpEventQueue();

      expect(received, [AudioInterruption.headphonesDisconnected]);
    });

    test('nothing is emitted after dispose', () async {
      await mapper.dispose();

      interruptions
          .add(AudioInterruptionEvent(true, AudioInterruptionType.pause));
      noisy.add(null);
      await pumpEventQueue();

      expect(received, isEmpty);
    });
  });

  test('NoAudioInterruptions never emits', () async {
    final events = <AudioInterruption>[];
    const NoAudioInterruptions().events.listen(events.add);
    await pumpEventQueue();

    expect(events, isEmpty);
  });
}
