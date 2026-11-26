import 'package:cantae/domain/entities/custom_naipe.dart';
import 'package:cantae/domain/entities/naipe.dart';

class SongTrack {
  final String id;
  final String filePath;
  final Naipe naipe;
  final int startDelayMs;
  final bool isPlayback;

  /// The named naipe when [naipe] is [Naipe.custom]. Null for the standard
  /// naipes and for synthetic tracks (the metronome click).
  final CustomNaipe? customNaipe;

  /// Original file name as picked ("tenor.mp3"); null for tracks received
  /// from a room or saved before this field existed.
  final String? fileName;

  final int? fileSizeBytes;

  const SongTrack({
    required this.id,
    required this.filePath,
    required this.naipe,
    this.startDelayMs = 0,
    this.isPlayback = false,
    this.customNaipe,
    this.fileName,
    this.fileSizeBytes,
  })  : assert(id.length > 0, 'SongTrack.id must not be empty'),
        assert(filePath.length > 0, 'SongTrack.filePath must not be empty'),
        assert(startDelayMs >= 0, 'SongTrack.startDelayMs must be >= 0'),
        assert(
          customNaipe == null || naipe == Naipe.custom,
          'Only a Naipe.custom track carries a custom naipe',
        );
}
