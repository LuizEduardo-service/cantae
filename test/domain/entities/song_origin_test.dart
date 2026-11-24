import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/domain/entities/song_origin.dart';

void main() {
  group('SongOrigin', () {
    test('has exactly the created and received values, in that order (LIB-12)',
        () {
      expect(
          SongOrigin.values, equals([SongOrigin.created, SongOrigin.received]));
    });
  });
}
