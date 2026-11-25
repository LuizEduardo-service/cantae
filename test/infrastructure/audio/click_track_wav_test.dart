import 'dart:typed_data';

import 'package:cantae/domain/audio/metronome_pulse_generator.dart';
import 'package:cantae/infrastructure/audio/click_track_wav.dart';
import 'package:flutter_test/flutter_test.dart';

// Failure modes (CLAUDE.md, testing rule 3), written before the code:
// 1. Wrong header sizes: players reject the file or read garbage length.
// 2. Wrong length: the click track ends before (or after) the song, so the
//    timeline duration changes.
// 3. Off-by-position: a beep lands at the wrong sample, i.e. off the beat.
// 4. Sound outside the beeps: the click track hisses between beats.
// 5. Downbeat not distinguishable from the other beats (RF50 accent).
// 6. A pulse near the end writes past the buffer and throws.
// 7. Zero duration: must still be a valid (empty) WAV.

const _sampleRate = 22050;

int _u32(Uint8List b, int offset) =>
    ByteData.sublistView(b).getUint32(offset, Endian.little);

int _u16(Uint8List b, int offset) =>
    ByteData.sublistView(b).getUint16(offset, Endian.little);

String _tag(Uint8List b, int offset) =>
    String.fromCharCodes(b.sublist(offset, offset + 4));

Int16List _samples(Uint8List wav) => ByteData.sublistView(wav, 44)
    .buffer
    .asInt16List(wav.offsetInBytes + 44, (wav.lengthInBytes - 44) ~/ 2);

int _sampleAt(int ms) => ms * _sampleRate ~/ 1000;

int _zeroCrossings(Int16List samples, int start, int count) {
  var crossings = 0;
  for (var i = start + 1; i < start + count; i++) {
    if ((samples[i - 1] < 0) != (samples[i] < 0)) crossings++;
  }
  return crossings;
}

void main() {
  group('ClickTrackWav.encode', () {
    test('writes a RIFF/WAVE PCM 16-bit mono 22050 Hz header', () {
      final wav = ClickTrackWav.encode(pulses: const [], durationMs: 1000);

      expect(_tag(wav, 0), 'RIFF');
      expect(_u32(wav, 4), wav.length - 8);
      expect(_tag(wav, 8), 'WAVE');
      expect(_tag(wav, 12), 'fmt ');
      expect(_u32(wav, 16), 16);
      expect(_u16(wav, 20), 1, reason: 'PCM');
      expect(_u16(wav, 22), 1, reason: 'mono');
      expect(_u32(wav, 24), _sampleRate);
      expect(_u32(wav, 28), _sampleRate * 2, reason: 'byte rate');
      expect(_u16(wav, 32), 2, reason: 'block align');
      expect(_u16(wav, 34), 16, reason: 'bits per sample');
      expect(_tag(wav, 36), 'data');
      expect(_u32(wav, 40), wav.length - 44);
    });

    test('lasts exactly durationMs', () {
      final wav = ClickTrackWav.encode(pulses: const [], durationMs: 2500);

      expect(_samples(wav).length, _sampleAt(2500));
    });

    test('each beep starts at its pulse sample, with silence before it', () {
      const pulses = [
        MetronomePulse(positionMs: 0, isDownbeat: true),
        MetronomePulse(positionMs: 833, isDownbeat: false),
        MetronomePulse(positionMs: 1667, isDownbeat: false),
      ];
      final samples =
          _samples(ClickTrackWav.encode(pulses: pulses, durationMs: 2000));

      for (final pulse in pulses) {
        final start = _sampleAt(pulse.positionMs);
        if (start > 0) {
          expect(samples[start - 1], 0,
              reason: 'silence before ${pulse.positionMs}');
        }
        expect(samples.sublist(start, start + 10).any((s) => s != 0), isTrue,
            reason: 'beep at ${pulse.positionMs}');
      }
    });

    test('is silent between beeps', () {
      const pulses = [
        MetronomePulse(positionMs: 0, isDownbeat: false),
        MetronomePulse(positionMs: 1000, isDownbeat: false),
      ];
      final samples =
          _samples(ClickTrackWav.encode(pulses: pulses, durationMs: 2000));

      // A beep lasts 30 ms; from 40 ms until the next pulse is silence.
      final gap = samples.sublist(_sampleAt(40), _sampleAt(1000));
      expect(gap.every((s) => s == 0), isTrue);
    });

    test('the downbeat beep is higher (more zero crossings)', () {
      const pulses = [
        MetronomePulse(positionMs: 0, isDownbeat: true),
        MetronomePulse(positionMs: 500, isDownbeat: false),
      ];
      final samples =
          _samples(ClickTrackWav.encode(pulses: pulses, durationMs: 1000));
      final beep = _sampleAt(25);

      final downbeat = _zeroCrossings(samples, 0, beep);
      final beat = _zeroCrossings(samples, _sampleAt(500), beep);

      expect(downbeat, greaterThan(beat));
    });

    test('a pulse near the end is cut at the end of the file, no error', () {
      const pulses = [MetronomePulse(positionMs: 990, isDownbeat: true)];

      final wav = ClickTrackWav.encode(pulses: pulses, durationMs: 1000);

      expect(_samples(wav).length, _sampleAt(1000));
    });

    test('pulses at or after the end are ignored', () {
      const pulses = [MetronomePulse(positionMs: 1000, isDownbeat: true)];

      final samples =
          _samples(ClickTrackWav.encode(pulses: pulses, durationMs: 1000));

      expect(samples.every((s) => s == 0), isTrue);
    });

    test('zero duration is a valid header with no samples', () {
      final wav = ClickTrackWav.encode(pulses: const [], durationMs: 0);

      expect(wav.length, 44);
      expect(_u32(wav, 40), 0);
    });
  });
}
