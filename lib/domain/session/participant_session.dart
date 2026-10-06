import 'dart:typed_data';

import 'ids.dart';

enum ParticipantRole { master, visitor }

enum ParticipantState {
  pendingApproval,
  approved,
  connected,
  rejected,
  disconnected,
  expired,
}

class ParticipantSession {
  final ParticipantId id;
  final ParticipantRole role;
  final ParticipantState state;
  final Uint8List? sessionKey;
  final int lastAcceptedSequence;
  final DateTime lastActivityAt;
  final DateTime? pendingSince;

  const ParticipantSession({
    required this.id,
    required this.role,
    required this.state,
    required this.sessionKey,
    required this.lastAcceptedSequence,
    required this.lastActivityAt,
    required this.pendingSince,
  });

  ParticipantSession copyWith({
    ParticipantState? state,
    Uint8List? sessionKey,
    int? lastAcceptedSequence,
    DateTime? lastActivityAt,
    DateTime? pendingSince,
    bool clearPendingSince = false,
  }) {
    return ParticipantSession(
      id: id,
      role: role,
      state: state ?? this.state,
      sessionKey: sessionKey ?? this.sessionKey,
      lastAcceptedSequence: lastAcceptedSequence ?? this.lastAcceptedSequence,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      pendingSince:
          clearPendingSince ? null : (pendingSince ?? this.pendingSince),
    );
  }
}
