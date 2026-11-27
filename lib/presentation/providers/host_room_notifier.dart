import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/song.dart';
import '../../domain/session/ids.dart';
import '../../domain/session/participant_session.dart';
import '../../domain/session/room_session_snapshot.dart';
import '../../domain/session/room_session_state_machine.dart';
import 'active_room_notifier.dart';
import 'room_providers.dart';
import 'song_repository_provider.dart';

enum HostRoomStatus { generating, ready, permissionDenied, failed }

/// A person as the room screens show them: never the session key.
class RoomPersonView {
  final ParticipantId id;
  final String name;

  const RoomPersonView({required this.id, required this.name});
}

/// Who is asking and who is in, from a room snapshot.
class HostPeople {
  final List<RoomPersonView> pending;
  final List<RoomPersonView> members;

  /// Every seat is taken, counting people still finishing the secure
  /// connection (ROOM-14, ROOM-54).
  final bool isFull;

  /// Anyone asking, connecting or in: leaving needs a confirmation.
  final bool hasPeople;

  const HostPeople({
    this.pending = const [],
    this.members = const [],
    this.isFull = false,
    this.hasPeople = false,
  });
}

/// Pending requests are listed; connected people are in the room; people
/// still finishing the secure connection are in neither list but hold a
/// seat (ROOM-12); refused, expired and gone people disappear.
HostPeople hostPeopleOf(RoomSessionSnapshot snapshot) {
  RoomPersonView view(ParticipantSession p) =>
      RoomPersonView(id: p.id, name: p.displayName);
  final pending = [
    for (final p in snapshot.participants)
      if (p.state == ParticipantState.pendingApproval) view(p),
  ];
  final members = [
    for (final p in snapshot.participants)
      if (p.state == ParticipantState.connected) view(p),
  ];
  final seated = snapshot.participants
      .where((p) =>
          p.state == ParticipantState.connected ||
          p.state == ParticipantState.approved)
      .length;
  return HostPeople(
    pending: pending,
    members: members,
    isFull: seated >= RoomSessionStateMachine.maxApprovedParticipants,
    hasPeople: pending.isNotEmpty || seated > 0,
  );
}

class HostRoomState {
  final HostRoomStatus status;
  final String? code;
  final String? songId;
  final String? songName;
  final HostPeople people;

  const HostRoomState({
    this.status = HostRoomStatus.generating,
    this.code,
    this.songId,
    this.songName,
    this.people = const HostPeople(),
  });

  HostRoomState copyWith({
    HostRoomStatus? status,
    String? code,
    HostPeople? people,
    String? songId,
    String? songName,
    bool clearSong = false,
  }) =>
      HostRoomState(
        status: status ?? this.status,
        code: code ?? this.code,
        people: people ?? this.people,
        songId: clearSong ? null : (songId ?? this.songId),
        songName: clearSong ? null : (songName ?? this.songName),
      );
}

/// Criar sala and the master's temporary room (ROOM-05..21, ROOM-39..41).
/// The room itself lives in [activeRoomProvider], so both screens show the
/// same room and code.
class HostRoomNotifier extends StateNotifier<HostRoomState> {
  HostRoomNotifier(this._ref) : super(const HostRoomState());

  final Ref _ref;
  StreamSubscription<RoomSessionSnapshot>? _snapshots;
  String? _masterName;
  String? _songId;

  ActiveRoomNotifier get _rooms => _ref.read(activeRoomProvider.notifier);

  /// Shows the hosted room, creating it as [masterName] when there is none.
  /// [songId] preselects the song (ROOM-07).
  Future<void> start({required String masterName, String? songId}) async {
    _masterName = masterName;
    _songId = songId;
    final active = _ref.read(activeRoomProvider);
    if (active != null && active.role == RoomRole.host) {
      _attach(active);
      return;
    }
    state = const HostRoomState();
    final song = songId == null ? null : await _songNamed(songId);
    final hosted =
        await _rooms.host(masterName: masterName, songName: song?.name);
    if (!mounted) return;
    hosted.when(
      success: (room) {
        state = state.copyWith(songId: song?.id, songName: song?.name);
        _attach(room);
      },
      failure: (f) => state = HostRoomState(
        status: f.code == 'discovery.permission-denied'
            ? HostRoomStatus.permissionDenied
            : HostRoomStatus.failed,
      ),
    );
  }

  /// "Tentar de novo" (ROOM-21).
  Future<void> retry() async {
    final name = _masterName;
    if (name != null) await start(masterName: name, songId: _songId);
  }

  /// "Abrir ajustes" (ROOM-20).
  Future<void> openSettings() =>
      _ref.read(systemSettingsProvider).openAppSettings();

  Future<void> approve(ParticipantId id) async {
    if (state.people.isFull) return;
    await _ref.read(activeRoomProvider)?.controller.approve(id);
  }

  void reject(ParticipantId id) =>
      _ref.read(activeRoomProvider)?.controller.reject(id);

  /// Picks or clears the room's song and announces it (ROOM-09).
  Future<void> chooseSong(Song? song) async {
    _songId = song?.id;
    await _rooms.changeSong(song?.name);
    if (!mounted) return;
    state = song == null
        ? state.copyWith(clearSong: true)
        : state.copyWith(songId: song.id, songName: song.name);
  }

  /// Ends the room for everyone (ROOM-18, ROOM-19, ROOM-41).
  Future<void> end() async {
    await _snapshots?.cancel();
    _snapshots = null;
    await _rooms.close();
  }

  void _attach(ActiveRoom room) {
    _snapshots?.cancel();
    final current = room.controller.currentSnapshot;
    state = HostRoomState(
      status: HostRoomStatus.ready,
      code: room.code,
      songId: state.songId ?? _songId,
      songName: room.songName,
      people: current == null ? const HostPeople() : hostPeopleOf(current),
    );
    _snapshots = room.controller.snapshots.listen((snapshot) {
      if (mounted) state = state.copyWith(people: hostPeopleOf(snapshot));
    });
  }

  Future<Song?> _songNamed(String id) async {
    final result = await _ref.read(songRepositoryProvider).getById(id);
    return result.when(success: (s) => s, failure: (_) => null);
  }

  @override
  void dispose() {
    _snapshots?.cancel();
    super.dispose();
  }
}

final hostRoomProvider =
    StateNotifierProvider.autoDispose<HostRoomNotifier, HostRoomState>(
  HostRoomNotifier.new,
);
