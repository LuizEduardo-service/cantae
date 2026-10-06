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
  final DateTime? approvedSince;

  const ParticipantSession({
    required this.id,
    required this.role,
    required this.state,
    required this.sessionKey,
    required this.lastAcceptedSequence,
    required this.lastActivityAt,
    required this.pendingSince,
    this.approvedSince,
  });

  ParticipantSession copyWith({
    ParticipantState? state,
    Uint8List? sessionKey,
    int? lastAcceptedSequence,
    DateTime? lastActivityAt,
    DateTime? pendingSince,
    DateTime? approvedSince,
    bool clearPendingSince = false,
    bool clearSessionKey = false,
    bool clearApprovedSince = false,
  }) {
    return ParticipantSession(
      id: id,
      role: role,
      state: state ?? this.state,
      sessionKey: clearSessionKey ? null : (sessionKey ?? this.sessionKey),
      lastAcceptedSequence: lastAcceptedSequence ?? this.lastAcceptedSequence,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      pendingSince:
          clearPendingSince ? null : (pendingSince ?? this.pendingSince),
      approvedSince:
          clearApprovedSince ? null : (approvedSince ?? this.approvedSince),
    );
  }
}
