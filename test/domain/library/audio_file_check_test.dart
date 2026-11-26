import 'dart:convert';

import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/library/audio_file_check.dart';
import 'package:cantae/domain/transfer/chunk_planner.dart';
import 'package:flutter_test/flutter_test.dart';

// Failure modes (UPL-07, UPL-08):
// - the format is taken from the extension instead of the bytes, so a text
//   file named ".mp3" passes;
// - RIFF containers that are not WAVE (AVI) pass as WAV;
// - an ADTS AAC header is read as MP3 (both start with 0xFF), or refused;
// - a header shorter than a signature crashes with a range error;
// - an empty file is reported as unsupported instead of unreadable;
// - the 100 MB limit is off by one, or is checked after the format so a
//   huge file is read first.
List<int> bytes(String ascii, [int padTo = audioHeaderLength]) {
  final b = ascii.codeUnits.toList();
  while (b.length < padTo) {
    b.add(0);
  }
  return b;
}

String? code(Result<AudioFormat, dynamic> r) =>
    r.when(success: (_) => null, failure: (f) => f.code);

void main() {
  group('detectAudioFormat', () {
    test('ID3 tag → mp3', () {
      expect(detectAudioFormat(bytes('ID3')), AudioFormat.mp3);
    });

    test('MPEG audio frame sync (layer III) → mp3', () {
      expect(
        detectAudioFormat([0xFF, 0xFB, 0x90, 0x64, 0, 0, 0, 0, 0, 0, 0, 0]),
        AudioFormat.mp3,
      );
    });

    test('ADTS header (layer 00) → aac, not mp3', () {
      expect(
        detectAudioFormat([0xFF, 0xF1, 0x50, 0x80, 0, 0, 0, 0, 0, 0, 0, 0]),
        AudioFormat.aac,
      );
    });

    test('ftyp box at offset 4 → m4a', () {
      final header = [0, 0, 0, 0x20, ...utf8.encode('ftypM4A ')];
      expect(detectAudioFormat(header), AudioFormat.m4a);
    });

    test('RIFF … WAVE → wav', () {
      expect(detectAudioFormat(bytes('RIFF\x24\x00\x00\x00WAVE')),
          AudioFormat.wav);
    });

    test('RIFF that is not WAVE (AVI) → null', () {
      expect(detectAudioFormat(bytes('RIFF\x24\x00\x00\x00AVI ')), isNull);
    });

    test('plain text named .mp3 → null', () {
      expect(detectAudioFormat(utf8.encode('Ave verum corpus')), isNull);
    });

    test('a PNG header → null', () {
      expect(
        detectAudioFormat(
            [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0]),
        isNull,
      );
    });

    test('a header shorter than any signature → null, no crash', () {
      expect(detectAudioFormat(const []), isNull);
      expect(detectAudioFormat(const [0xFF]), isNull);
      expect(detectAudioFormat(utf8.encode('RIFF')), isNull);
      expect(detectAudioFormat(utf8.encode('ID')), isNull);
    });

    test('each format has the extension the library file uses', () {
      expect(AudioFormat.mp3.extension, 'mp3');
      expect(AudioFormat.aac.extension, 'aac');
      expect(AudioFormat.m4a.extension, 'm4a');
      expect(AudioFormat.wav.extension, 'wav');
    });
  });

  group('checkTrackFile', () {
    final wav = bytes('RIFF\x24\x00\x00\x00WAVE');
    const limit = ChunkPlanner.maxTransferableSizeBytes;

    test('an empty file → track_file_empty', () {
      expect(code(checkTrackFile(sizeBytes: 0, header: const [])),
          'track_file_empty');
    });

    test('exactly 100 MB is accepted', () {
      expect(checkTrackFile(sizeBytes: limit, header: wav).isSuccess, isTrue);
    });

    test('100 MB + 1 byte → track_file_too_large', () {
      expect(code(checkTrackFile(sizeBytes: limit + 1, header: wav)),
          'track_file_too_large');
    });

    test('size is checked before the format', () {
      expect(
        code(checkTrackFile(sizeBytes: limit + 1, header: const [])),
        'track_file_too_large',
      );
    });

    test('a non-audio header → track_file_unsupported', () {
      expect(
        code(checkTrackFile(sizeBytes: 16, header: utf8.encode('hello'))),
        'track_file_unsupported',
      );
    });

    test('a valid file returns its format', () {
      expect(
        checkTrackFile(sizeBytes: 2048, header: wav)
            .when(success: (f) => f, failure: (_) => null),
        AudioFormat.wav,
      );
    });
  });
}
