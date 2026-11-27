import '../core/failures.dart';
import '../core/result.dart';

/// Version of the room wire protocol (AD-015). Bump it on any change to the
/// session wire format; the master refuses a different version.
const int roomProtocolVersion = 1;

/// Longest name shown in a room (ROOM-02).
const int displayNameMaxLength = 40;

const String _unnamed = 'Sem nome';

/// Checks the name a person types for the room. Returns it trimmed.
Result<String, ValidationFailure> validateDisplayName(String raw) {
  final name = raw.trim();
  if (name.isEmpty) {
    return Result.failure(ValidationFailure(code: 'display_name_empty'));
  }
  if (name.length > displayNameMaxLength) {
    return Result.failure(ValidationFailure(code: 'display_name_too_long'));
  }
  return Result.success(name);
}

final RegExp _controlCharacters = RegExp(r'[\u0000-\u001F\u007F-\u009F]');

/// Makes a name that came over the network safe to show: no control
/// characters, at most [displayNameMaxLength] characters, never empty.
String sanitizeRemoteDisplayName(String raw) {
  final cleaned = raw.replaceAll(_controlCharacters, '').trim();
  if (cleaned.isEmpty) return _unnamed;
  final runes = cleaned.runes;
  if (runes.length <= displayNameMaxLength) return cleaned;
  return String.fromCharCodes(runes.take(displayNameMaxLength)).trim();
}

/// How a request to join a room ended, as the singer sees it.
enum JoinOutcome {
  joined,
  rejected,
  roomFull,
  protocolMismatch,
  expired,
  connectionLost,
  invalidCode,
  cancelled,
}

const Map<String, JoinOutcome> _outcomeByCode = {
  'session.rejected': JoinOutcome.rejected,
  'session.room-full': JoinOutcome.roomFull,
  'session.protocol-mismatch': JoinOutcome.protocolMismatch,
  'session.request-expired': JoinOutcome.expired,
  'session.invalid-code': JoinOutcome.invalidCode,
  'session.join-cancelled': JoinOutcome.cancelled,
};

/// Maps a join failure to its outcome. Any other code is a network problem.
JoinOutcome joinOutcomeFor(Failure failure) =>
    _outcomeByCode[failure.code] ?? JoinOutcome.connectionLost;
