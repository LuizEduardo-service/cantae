import 'package:cantae/data/ids/uuid_v4.dart';
import 'package:flutter_test/flutter_test.dart';

// Failure modes: wrong version/variant bits (not a v4 UUID, as the PRD's
// RehearsalLog.id requires); repeated ids overwrite rehearsals.
void main() {
  test('is a lowercase RFC 4122 version 4 UUID', () {
    expect(
      uuidV4(),
      matches(RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      )),
    );
  });

  test('1000 calls give 1000 distinct ids', () {
    expect({for (var i = 0; i < 1000; i++) uuidV4()}, hasLength(1000));
  });
}
