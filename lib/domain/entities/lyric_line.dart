import 'package:cantae/domain/entities/naipe.dart';

class LyricLine {
  final String text;
  final int onsetMs;
  final Naipe? naipe;
  final String? dynamics;

  const LyricLine({
    required this.text,
    required this.onsetMs,
    this.naipe,
    this.dynamics,
  })  : assert(text.length > 0, 'LyricLine.text must not be empty'),
        assert(onsetMs >= 0, 'LyricLine.onsetMs must be >= 0');
}
