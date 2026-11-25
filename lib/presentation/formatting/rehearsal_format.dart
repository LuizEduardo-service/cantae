const List<String> _months = [
  'jan',
  'fev',
  'mar',
  'abr',
  'mai',
  'jun',
  'jul',
  'ago',
  'set',
  'out',
  'nov',
  'dez',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// `m:ss` below one hour, `h:mm:ss` from one hour (rehearsal durations).
String formatDuration(int ms) {
  final totalSeconds = ms ~/ 1000;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours == 0) return '$minutes:${_two(seconds)}';
  return '$hours:${_two(minutes)}:${_two(seconds)}';
}

/// "25 nov 2026 · 19:40" (pt-BR, no localization package yet).
String formatRehearsalDate(DateTime at) =>
    '${at.day} ${_months[at.month - 1]} ${at.year} · '
    '${_two(at.hour)}:${_two(at.minute)}';
