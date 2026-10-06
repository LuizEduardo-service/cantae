import 'package:cantae/domain/entities/naipe.dart';

class SongTrack {
  final String id;
  final String filePath;
  final Naipe naipe;
  final int startDelayMs;
  final bool isPlayback;

  const SongTrack({
    required this.id,
    required this.filePath,
    required this.naipe,
    this.startDelayMs = 0,
    this.isPlayback = false,
  })  : assert(id.length > 0, 'SongTrack.id must not be empty'),
        assert(filePath.length > 0, 'SongTrack.filePath must not be empty'),
        assert(startDelayMs >= 0, 'SongTrack.startDelayMs must be >= 0');
}
