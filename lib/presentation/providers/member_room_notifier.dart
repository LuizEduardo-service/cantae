import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/core/unit.dart';
import 'active_room_notifier.dart';

class MemberRoomState {
  /// False when this device is not in a room as a singer (the screen goes
  /// back to the Biblioteca).
  final bool inRoom;
  final String masterName;
  final String? songName;

  /// The master ended the room or the connection dropped (ROOM-44).
  final bool lost;

  const MemberRoomState({
    required this.inRoom,
    this.masterName = '',
    this.songName,
    this.lost = false,
  });
}

/// The singer's temporary room (ROOM-42..44).
class MemberRoomNotifier extends StateNotifier<MemberRoomState> {
  MemberRoomNotifier(Ref ref)
      : _rooms = ref.read(activeRoomProvider.notifier),
        super(_initial(ref.read(activeRoomProvider))) {
    final room = ref.read(activeRoomProvider);
    if (room != null && room.role == RoomRole.member) {
      _lost = room.controller.masterConnectionLost.listen(_onLost);
    }
  }

  final ActiveRoomNotifier _rooms;
  StreamSubscription<Unit>? _lost;

  static MemberRoomState _initial(ActiveRoom? room) =>
      room == null || room.role != RoomRole.member
          ? const MemberRoomState(inRoom: false)
          : MemberRoomState(
              inRoom: true,
              masterName: room.masterName,
              songName: room.songName,
            );

  /// "Sair da sala" (ROOM-43).
  Future<void> leave() async {
    await _lost?.cancel();
    _lost = null;
    await _rooms.close();
    if (mounted) state = const MemberRoomState(inRoom: false);
  }

  void _onLost(Unit _) {
    _lost?.cancel();
    _lost = null;
    unawaited(_rooms.close());
    if (!mounted) return;
    state = MemberRoomState(
      inRoom: false,
      masterName: state.masterName,
      songName: state.songName,
      lost: true,
    );
  }

  @override
  void dispose() {
    _lost?.cancel();
    super.dispose();
  }
}

final memberRoomProvider =
    StateNotifierProvider.autoDispose<MemberRoomNotifier, MemberRoomState>(
  MemberRoomNotifier.new,
);
