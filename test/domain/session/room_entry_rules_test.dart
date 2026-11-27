import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/session/room_entry_rules.dart';
import 'package:flutter_test/flutter_test.dart';

// Failure modes (ROOM-02, ROOM-34..36, ROOM-48):
// - a blank name, or one over 40 characters, is accepted;
// - a valid name keeps the spaces around it;
// - a name that came over the network shows control characters, takes
//   more than one line of the master's screen, or shows up empty;
// - a refusal reason maps to the wrong banner, or an unknown code maps to
//   a banner that blames the person (rejected/full) instead of the network.
String? _nameError(String raw) =>
    validateDisplayName(raw).when(success: (_) => null, failure: (f) => f.code);

String _validName(String raw) => validateDisplayName(raw)
    .when(success: (n) => n, failure: (f) => fail(f.code));

void main() {
  group('validateDisplayName (ROOM-02)', () {
    test('a blank name is refused', () {
      expect(_nameError(''), 'display_name_empty');
      expect(_nameError('   '), 'display_name_empty');
    });

    test('1 and 40 characters are accepted, trimmed', () {
      expect(_validName(' M '), 'M');
      expect(_validName('${'a' * 40}  '), 'a' * 40);
    });

    test('41 characters are refused', () {
      expect(displayNameMaxLength, 40);
      expect(_nameError('a' * 41), 'display_name_too_long');
    });
  });

  group('sanitizeRemoteDisplayName', () {
    test('drops control characters and trims', () {
      expect(sanitizeRemoteDisplayName(' Mari\u0000na\n\t '), 'Marina');
    });

    test('cuts a long name at 40 characters', () {
      expect(sanitizeRemoteDisplayName('b' * 200), 'b' * 40);
    });

    test('an empty or blank name becomes "Sem nome"', () {
      expect(sanitizeRemoteDisplayName(''), 'Sem nome');
      expect(sanitizeRemoteDisplayName('  \u0007 '), 'Sem nome');
    });

    test('keeps accents', () {
      expect(sanitizeRemoteDisplayName('João Conceição'), 'João Conceição');
    });
  });

  test('the room protocol version is 1', () {
    expect(roomProtocolVersion, 1);
  });

  group('joinOutcomeFor', () {
    final cases = {
      'session.rejected': JoinOutcome.rejected,
      'session.room-full': JoinOutcome.roomFull,
      'session.protocol-mismatch': JoinOutcome.protocolMismatch,
      'session.request-expired': JoinOutcome.expired,
      'session.invalid-code': JoinOutcome.invalidCode,
      'session.join-cancelled': JoinOutcome.cancelled,
      'session.connection-lost': JoinOutcome.connectionLost,
      'session.connect-failed': JoinOutcome.connectionLost,
    };
    for (final entry in cases.entries) {
      test('${entry.key} → ${entry.value.name}', () {
        expect(
          joinOutcomeFor(ValidationFailure(code: entry.key)),
          entry.value,
        );
      });
    }

    test('an unknown code is treated as a network problem', () {
      expect(
        joinOutcomeFor(NetworkFailure(code: 'session.handshake-failed')),
        JoinOutcome.connectionLost,
      );
    });
  });
}
