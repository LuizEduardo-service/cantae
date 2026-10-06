import 'package:cantae/domain/entities/naipe.dart';

class SongTrack {
  final String id;
  final String filePath;
  final Naipe naipe;
  final int startDelayMs;

  const SongTrack({
    required this.id,
    required this.filePath,
    required this.naipe,
    this.startDelayMs = 0,
  });
}
