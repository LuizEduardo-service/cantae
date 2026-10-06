final class LoopController {
  final int startMs;
  final int endMs;
  final int maxMs;

  const LoopController({
    required this.startMs,
    required this.endMs,
    required this.maxMs,
  });

  bool get isValid =>
      startMs >= 0 && endMs > startMs && endMs <= maxMs;

  bool shouldReposition(int currentMs) => isValid && currentMs >= endMs;

  int get repositionTarget => startMs;
}
