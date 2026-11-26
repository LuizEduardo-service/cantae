import 'dart:convert';
import 'dart:io';

import 'package:cantae/data/library/track_file_inspector.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/library/audio_file_check.dart';
import 'package:cantae/domain/library/track_file_picker.dart';
import 'package:cantae/domain/transfer/chunk_planner.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

// Failure modes (UPL-07, UPL-08, UPL-09):
// - the format comes from the ".mp3" extension, so a text file passes;
// - an empty file is reported as unsupported or crashes;
// - a file over 100 MB is read and hashed before being refused, or its junk
//   header wins over the size;
// - a missing or unreadable path throws instead of a rejection;
// - the SHA-256 or size reported differs from the real file;
// - the picked name is lost (the row must show it).
List<int> wavBytes(int length) {
  final header = ascii.encode('RIFF\x24\x00\x00\x00WAVEfmt ');
  return [...header, ...List<int>.filled(length - header.length, 7)];
}

String? codeOf(Result<InspectedTrackFile, dynamic> r) =>
    r.when(success: (_) => null, failure: (f) => f.code);

void main() {
  late Directory dir;
  const inspector = TrackFileInspector();

  setUp(() => dir = Directory.systemTemp.createTempSync('cantae_inspect'));
  tearDown(() => dir.deleteSync(recursive: true));

  PickedTrackFile write(String name, List<int> bytes) {
    final file = File(p.join(dir.path, name))..writeAsBytesSync(bytes);
    return PickedTrackFile(path: file.path, name: name);
  }

  test('a WAV file comes back with its format, size, hash and name', () async {
    final bytes = wavBytes(4096);
    final picked = write('soprano.wav', bytes);

    final result = await inspector.inspect(picked);

    final file = result.when(success: (f) => f, failure: (f) => fail(f.code));
    expect(file.format, AudioFormat.wav);
    expect(file.sizeBytes, 4096);
    expect(file.sha256, sha256.convert(bytes).toString());
    expect(file.name, 'soprano.wav');
    expect(file.sourcePath, picked.path);
  });

  test('a text file named .mp3 is unsupported', () async {
    final picked = write('tenor.mp3', utf8.encode('Ave verum corpus natum'));

    expect(codeOf(await inspector.inspect(picked)), 'track_file_unsupported');
  });

  test('an empty file is refused as empty', () async {
    final picked = write('baixo.mp3', const []);

    expect(codeOf(await inspector.inspect(picked)), 'track_file_empty');
  });

  test('a file over 100 MB is too large even with a junk header', () async {
    final path = p.join(dir.path, 'grande.wav');
    final raf = File(path).openSync(mode: FileMode.write)
      ..truncateSync(ChunkPlanner.maxTransferableSizeBytes + 1);
    raf.closeSync();

    final result = await inspector.inspect(
      PickedTrackFile(path: path, name: 'grande.wav'),
    );

    expect(codeOf(result), 'track_file_too_large');
  });

  test('a missing file is unreadable, not an exception', () async {
    final result = await inspector.inspect(
      PickedTrackFile(path: p.join(dir.path, 'sumiu.mp3'), name: 'sumiu.mp3'),
    );

    expect(codeOf(result), 'track_file_unreadable');
  });
}
