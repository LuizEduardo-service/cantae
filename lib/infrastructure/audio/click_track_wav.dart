import 'dart:math';
import 'dart:typed_data';

import 'package:cantae/domain/audio/metronome_pulse_generator.dart';

/// Encodes a metronome click track as a WAV file (RIFF, PCM 16-bit mono).
///
/// Silence everywhere except a short sine beep at each pulse: 1500 Hz on a
/// downbeat, 1000 Hz otherwise, with a linear fade-out so it does not pop.
/// The file lasts exactly `durationMs`, so it lines up with the song on the
/// shared timeline.
abstract final class ClickTrackWav {
  static const int defaultSampleRate = 22050;
  static const int _beepMs = 30;
  static const double _amplitude = 0.6 * 32767;

  static Uint8List encode({
    required List<MetronomePulse> pulses,
    required int durationMs,
    int sampleRate = defaultSampleRate,
  }) {
    final sampleCount = durationMs <= 0 ? 0 : durationMs * sampleRate ~/ 1000;
    final samples = Int16List(sampleCount);
    final beepSamples = _beepMs * sampleRate ~/ 1000;

    for (final pulse in pulses) {
      final start = pulse.positionMs * sampleRate ~/ 1000;
      if (start < 0 || start >= sampleCount) continue;
      final frequency = pulse.isDownbeat ? 1500.0 : 1000.0;
      for (var i = 0; i < beepSamples && start + i < sampleCount; i++) {
        final fade = 1 - i / beepSamples;
        samples[start + i] =
            (_amplitude * fade * sin(2 * pi * frequency * i / sampleRate))
                .round();
      }
    }

    return _withHeader(samples, sampleRate);
  }

  static Uint8List _withHeader(Int16List samples, int sampleRate) {
    final dataBytes = samples.lengthInBytes;
    final bytes = ByteData(44 + dataBytes);
    void tag(int offset, String value) {
      for (var i = 0; i < 4; i++) {
        bytes.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    tag(0, 'RIFF');
    bytes.setUint32(4, 36 + dataBytes, Endian.little);
    tag(8, 'WAVE');
    tag(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little); // fmt chunk size
    bytes.setUint16(20, 1, Endian.little); // PCM
    bytes.setUint16(22, 1, Endian.little); // mono
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    bytes.setUint16(32, 2, Endian.little); // block align
    bytes.setUint16(34, 16, Endian.little); // bits per sample
    tag(36, 'data');
    bytes.setUint32(40, dataBytes, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      bytes.setInt16(44 + i * 2, samples[i], Endian.little);
    }
    return bytes.buffer.asUint8List();
  }
}
