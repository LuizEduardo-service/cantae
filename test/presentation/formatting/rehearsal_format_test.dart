import 'package:cantae/presentation/formatting/rehearsal_format.dart';
import 'package:flutter_test/flutter_test.dart';

// Failure modes: seconds not zero-padded; hours shown as 62 minutes; the
// month in English or numeric; minutes of the time not zero-padded.
void main() {
  group('formatDuration', () {
    test('m:ss below one hour', () {
      expect(formatDuration(0), '0:00');
      expect(formatDuration(59000), '0:59');
      expect(formatDuration(750000), '12:30');
      expect(formatDuration(3599999), '59:59');
    });

    test('h:mm:ss from one hour', () {
      expect(formatDuration(3600000), '1:00:00');
      expect(formatDuration(3723000), '1:02:03');
    });
  });

  test('formatRehearsalDate: day, pt-BR month, year · hh:mm', () {
    expect(formatRehearsalDate(DateTime(2026, 11, 25, 19, 40)),
        '25 nov 2026 · 19:40');
    expect(
        formatRehearsalDate(DateTime(2026, 2, 3, 7, 5)), '3 fev 2026 · 07:05');
  });
}
