import 'package:cantae/presentation/theme/cantae_typography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CantaeTypography font families', () {
    test('lyricActive uses the Geist family', () {
      expect(CantaeTypography.lyricActive.fontFamily, 'Geist');
    });

    test('mono uses the Geist Mono family', () {
      expect(CantaeTypography.mono.fontFamily, 'Geist Mono');
    });

    test('monoLarge and monoInput also use the Geist Mono family', () {
      expect(CantaeTypography.monoLarge.fontFamily, 'Geist Mono');
      expect(CantaeTypography.monoInput.fontFamily, 'Geist Mono');
    });
  });
}
