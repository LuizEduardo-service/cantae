import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/transfer/chunk_planner.dart';

/// How many leading bytes [detectAudioFormat] needs to see.
const int audioHeaderLength = 12;

/// Audio formats a track may have (MP3, M4A/AAC, WAV), recognised by
/// content, never by the file extension (RNF-SEC-06).
enum AudioFormat {
  mp3('mp3'),
  aac('aac'),
  m4a('m4a'),
  wav('wav');

  const AudioFormat(this.extension);

  /// Extension of the content-addressed library file.
  final String extension;
}

bool _matches(List<int> header, int offset, String ascii) {
  if (header.length < offset + ascii.length) return false;
  for (var i = 0; i < ascii.length; i++) {
    if (header[offset + i] != ascii.codeUnitAt(i)) return false;
  }
  return true;
}

/// The format whose signature [header] starts with, or null.
AudioFormat? detectAudioFormat(List<int> header) {
  if (_matches(header, 0, 'ID3')) return AudioFormat.mp3;
  if (_matches(header, 4, 'ftyp')) return AudioFormat.m4a;
  if (_matches(header, 0, 'RIFF') && _matches(header, 8, 'WAVE')) {
    return AudioFormat.wav;
  }
  if (header.length >= 2 && header[0] == 0xFF) {
    final b1 = header[1];
    // ADTS: 12-bit sync, layer bits 00.
    if (b1 & 0xF6 == 0xF0) return AudioFormat.aac;
    // MPEG audio frame: 11-bit sync, layer bits not 00 (reserved).
    if (b1 & 0xE0 == 0xE0 && (b1 >> 1) & 0x03 != 0) return AudioFormat.mp3;
  }
  return null;
}

/// Decides whether a file of [sizeBytes] starting with [header] may enter
/// the library (UPL-07, UPL-08). Size is checked first, so a huge file is
/// refused before anyone reads it.
Result<AudioFormat, ValidationFailure> checkTrackFile({
  required int sizeBytes,
  required List<int> header,
}) {
  if (sizeBytes <= 0) {
    return Result.failure(ValidationFailure(code: 'track_file_empty'));
  }
  if (sizeBytes > ChunkPlanner.maxTransferableSizeBytes) {
    return Result.failure(ValidationFailure(code: 'track_file_too_large'));
  }
  final format = detectAudioFormat(header);
  if (format == null) {
    return Result.failure(ValidationFailure(code: 'track_file_unsupported'));
  }
  return Result.success(format);
}
