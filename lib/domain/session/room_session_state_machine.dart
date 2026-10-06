import 'dart:typed_data';

import '../core/failures.dart';
import '../core/result.dart';
import '../core/unit.dart';
import 'envelope.dart';
import 'envelope_authenticator.dart';
import 'ids.dart';
import 'participant_session.dart';
import 'room.dart';

class RoomSessionStateMachine {
  static const maxApprovedParticipants = 8;
  static const pendingApprovalTtl = Duration(seconds: 60);
  static const connectedInactivityTtl = Duration(minutes: 30);

  Room _room;
  final Map<ParticipantId, ParticipantSession> _participants = {};
  final EnvelopeAuthenticator _authenticator;

  RoomSessionStateMachine(
      {required Room room, EnvelopeAuthenticator? authenticator})
      : _room = room,
        _authenticator = authenticator ?? EnvelopeAuthenticator();

  Room get room => _room;

  ParticipantSession? participant(ParticipantId id) => _participants[id];

  Result<Unit, Failure> requestJoin(DeviceId id, String code, DateTime now) {
    if (code != _room.code) {
      return Result.failure(ValidationFailure(code: 'session.invalid-code'));
    }
    if (_admittedCount() >= maxApprovedParticipants) {
      return Result.failure(ValidationFailure(code: 'session.room-full'));
    }

    final participantId = ParticipantId(id.value);
    _participants[participantId] = ParticipantSession(
      id: participantId,
      role: ParticipantRole.visitor,
      state: ParticipantState.pendingApproval,
      sessionKey: null,
      lastAcceptedSequence: -1,
      lastActivityAt: now,
      pendingSince: now,
    );
    return const Result.success(Unit());
  }

  Result<ParticipantId, Failure> approve(ParticipantId id, DateTime now) {
    final session = _participants[id];
    if (session == null) {
      return Result.failure(
        NotFoundFailure(code: 'session.participant-not-found'),
      );
    }
    if (session.state != ParticipantState.pendingApproval) {
      return Result.failure(
        ValidationFailure(code: 'session.participant-not-pending'),
      );
    }
    if (_admittedCount() >= maxApprovedParticipants) {
      return Result.failure(ValidationFailure(code: 'session.room-full'));
    }

    _participants[id] = session.copyWith(
      state: ParticipantState.approved,
      lastActivityAt: now,
      clearPendingSince: true,
    );
    return Result.success(id);
  }

  Result<Unit, Failure> reject(ParticipantId id) {
    final session = _participants[id];
    if (session == null) {
      return Result.failure(
        NotFoundFailure(code: 'session.participant-not-found'),
      );
    }
    if (session.state != ParticipantState.pendingApproval) {
      return Result.failure(
        ValidationFailure(code: 'session.participant-not-pending'),
      );
    }

    _participants[id] = session.copyWith(
      state: ParticipantState.rejected,
      clearPendingSince: true,
    );
    return const Result.success(Unit());
  }

  Result<Unit, Failure> completeHandshake(
      ParticipantId id, Uint8List sessionKey) {
    final session = _participants[id];
    if (session == null) {
      return Result.failure(
        NotFoundFailure(code: 'session.participant-not-found'),
      );
    }
    if (session.state != ParticipantState.approved) {
      return Result.failure(
        ValidationFailure(code: 'session.participant-not-approved'),
      );
    }

    _participants[id] = session.copyWith(
      state: ParticipantState.connected,
      sessionKey: sessionKey,
    );
    return const Result.success(Unit());
  }

  Result<Unit, Failure> acceptEnvelope(
    Envelope envelope,
    DateTime now, {
    bool requiresMasterRole = false,
  }) {
    final session = _participants[envelope.senderId];
    final sessionKey = session?.sessionKey;
    if (session == null ||
        session.state != ParticipantState.connected ||
        sessionKey == null) {
      return Result.failure(
        NotFoundFailure(code: 'session.participant-not-found'),
      );
    }

    final verifyResult = _authenticator.verify(
      envelope,
      sessionKey,
      session.lastAcceptedSequence,
    );
    if (verifyResult.isFailure) {
      return verifyResult;
    }

    if (requiresMasterRole && session.role != ParticipantRole.master) {
      return Result.failure(
        ValidationFailure(code: 'session.unauthorized-role'),
      );
    }

    _participants[envelope.senderId] = session.copyWith(
      lastAcceptedSequence: envelope.sequence,
      lastActivityAt: now,
    );
    return const Result.success(Unit());
  }

  Result<Unit, Failure> disconnect(ParticipantId id) {
    final session = _participants[id];
    if (session == null) {
      return Result.failure(
        NotFoundFailure(code: 'session.participant-not-found'),
      );
    }

    _participants[id] = session.copyWith(
      state: ParticipantState.disconnected,
      clearSessionKey: true,
      clearPendingSince: true,
    );
    return const Result.success(Unit());
  }

  Unit endRoom() {
    for (final entry in _participants.entries.toList()) {
      _participants[entry.key] = entry.value.copyWith(
        state: ParticipantState.disconnected,
        clearSessionKey: true,
        clearPendingSince: true,
      );
    }
    _room = _room.copyWith(state: RoomLifecycle.ended);
    return const Unit();
  }

  Unit tick(DateTime now) {
    for (final entry in _participants.entries.toList()) {
      final session = entry.value;
      final pendingSince = session.pendingSince;
      if (session.state == ParticipantState.pendingApproval &&
          pendingSince != null &&
          now.difference(pendingSince) > pendingApprovalTtl) {
        _participants[entry.key] = session.copyWith(
          state: ParticipantState.rejected,
          clearPendingSince: true,
        );
        continue;
      }
      if (session.state == ParticipantState.connected &&
          now.difference(session.lastActivityAt) > connectedInactivityTtl) {
        _participants[entry.key] = session.copyWith(
          state: ParticipantState.expired,
        );
      }
    }
    return const Unit();
  }

  int _admittedCount() => _participants.values
      .where(
        (p) =>
            p.state == ParticipantState.approved ||
            p.state == ParticipantState.connected,
      )
      .length;
}
