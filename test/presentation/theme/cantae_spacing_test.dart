import 'package:cantae/presentation/theme/cantae_spacing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CantaeSpacing', () {
    test('exposes the documented 4pt scale', () {
      expect(CantaeSpacing.space1, 4);
      expect(CantaeSpacing.space2, 8);
      expect(CantaeSpacing.space3, 12);
      expect(CantaeSpacing.space4, 16);
      expect(CantaeSpacing.space5, 20);
      expect(CantaeSpacing.space6, 24);
    });
  });

  group('CantaeRadii.radiusPill', () {
    test('returns height divided by 2', () {
      expect(CantaeRadii.radiusPill(48), 24);
      expect(CantaeRadii.radiusPill(32), 16);
    });
  });
}
