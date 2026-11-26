/// "12,4 MB" (pt-BR decimal comma, one decimal place).
String formatMegabytes(int bytes) {
  final mb = (bytes / (1024 * 1024)).toStringAsFixed(1);
  return '${mb.replaceAll('.', ',')} MB';
}
