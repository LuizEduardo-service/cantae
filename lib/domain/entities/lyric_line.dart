import 'package:cantae/domain/entities/naipe.dart';

class LyricLine {
  final String text;
  final int onsetMs;
  final Naipe? naipe;

  const LyricLine({
    required this.text,
    required this.onsetMs,
    this.naipe,
  });
}
