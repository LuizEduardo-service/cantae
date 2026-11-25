import 'dart:io';
import 'dart:typed_data';

import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/entities/metronome_config.dart';
import 'package:cantae/infrastructure/audio/file_click_track_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

Int16List _samples(File wav) {
  final bytes = wav.readAsBytesSync();
  return ByteData.sublistView(bytes, 44)
      .buffer
      .asInt16List(bytes.offsetInBytes + 44, (bytes.length - 44) ~/ 2);
}

int _zeroCrossings(Int16List samples, int start, int count) {
  var crossings = 0;
  for (var i = start + 1; i < start + count; i++) {
    if ((samples[i - 1] < 0) != (samples[i] < 0)) crossings++;
  }
  return crossings;
}

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('cantae_click_'));
  tearDown(() => temp.deleteSync(recursive: true));

  group('FileClickTrackBuilder', () {
    test('writes metronome_<songId>.wav and returns its path', () async {
      final builder = FileClickTrackBuilder(directory: () async => temp);

      final result = await builder.build(
        songId: 'ave',
        config: const MetronomeConfig(bpm: 120, beatsPerMeasure: 4),
        durationMs: 2000,
      );

      final path = result.when(success: (path) => path, failure: (_) => null);
      expect(path, p.join(temp.path, 'metronome_ave.wav'));
      final file = File(path!);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), 44 + 2000 * 22050 ~/ 1000 * 2);
    });

    test('with the accent off, the first beat sounds like the others',
        () async {
      final builder = FileClickTrackBuilder(directory: () async => temp);

      final result = await builder.build(
        songId: 'ave',
        config: const MetronomeConfig(
          bpm: 120,
          beatsPerMeasure: 4,
          downbeatAccent: false,
        ),
        durationMs: 1000,
      );

      final samples = _samples(File(result.when(
        success: (path) => path,
        failure: (failure) => fail('$failure'),
      )));
      const beep = 25 * 22050 ~/ 1000;
      expect(
        _zeroCrossings(samples, 0, beep),
        _zeroCrossings(samples, 500 * 22050 ~/ 1000, beep),
      );
    });

    test('a second build overwrites the same file', () async {
      final builder = FileClickTrackBuilder(directory: () async => temp);
      const config = MetronomeConfig(bpm: 60, beatsPerMeasure: 4);

      await builder.build(songId: 'ave', config: config, durationMs: 3000);
      final second =
          await builder.build(songId: 'ave', config: config, durationMs: 1000);

      final path = second.when(success: (path) => path, failure: (_) => '');
      expect(File(path).lengthSync(), 44 + 1000 * 22050 ~/ 1000 * 2);
      expect(temp.listSync(), hasLength(1));
    });

    test('an unwritable directory is a PlaybackFailure, not an exception',
        () async {
      final builder = FileClickTrackBuilder(
        directory: () async => Directory(p.join(temp.path, 'missing', 'dir')),
      );

      final result = await builder.build(
        songId: 'ave',
        config: const MetronomeConfig(bpm: 60, beatsPerMeasure: 4),
        durationMs: 1000,
      );

      final failure =
          result.when(success: (_) => null, failure: (failure) => failure);
      expect(failure, isA<PlaybackFailure>());
      expect(failure!.code, 'click_track_build_failed');
    });
  });
}
