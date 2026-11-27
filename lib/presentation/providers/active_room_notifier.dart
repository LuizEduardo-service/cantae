import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/session/room_session_controller.dart';
import '../../domain/core/failures.dart';
import '../../domain/core/result.dart';
import '../../domain/repositories/local_profile_repository.dart';
import '../../domain/session/ids.dart';
import '../../domain/session/room_discovery.dart';
import '../../domain/session/room_entry_rules.dart';
import 'room_providers.dart';

enum RoomRole { host, member }

/// The one room this device is in (ROOM-47).
class ActiveRoom {
  final RoomRole role;
  final RoomSessionController controller;
  final RoomId roomId;

  /// The room's code; known only to the host.
  final String? code;
  final String masterName;
  final String? songName;

  const ActiveRoom({
    required this.role,
    required this.controller,
    required this.roomId,
    required this.masterName,
    this.code,
    this.songName,
  });

  ActiveRoom withSong(String? song) => ActiveRoom(
        role: role,
        controller: controller,
        roomId: roomId,
        masterName: masterName,
        code: code,
        songName: song,
      );
}

/// Holds the active room and the controller used to look for one. Search
/// and request share a controller, since it remembers the rooms it found.
class ActiveRoomNotifier extends StateNotifier<ActiveRoom?> {
  ActiveRoomNotifier({
    required RoomSessionController Function(DeviceId self) newController,
    required LocalProfileRepository profiles,
  })  : _newController = newController,
        _profiles = profiles,
        super(null);

  final RoomSessionController Function(DeviceId self) _newController;
  final LocalProfileRepository _profiles;
  RoomSessionController? _searching;

  /// Hosts a new room as [masterName], closing any room this device is in.
  Future<Result<ActiveRoom, Failure>> host({
    required String masterName,
    String? songName,
  }) async {
    await close();
    final controller = await _controllerForThisDevice();
    if (controller == null) {
      return Result.failure(StorageFailure(code: 'local_profile_read_failed'));
    }
    final created =
        await controller.createRoom(masterName: masterName, songName: songName);
    return created.when(
      success: (roomId) {
        final room = ActiveRoom(
          role: RoomRole.host,
          controller: controller,
          roomId: roomId,
          masterName: masterName,
          code: controller.roomCode,
          songName: songName,
        );
        if (mounted) state = room;
        return Result.success(room);
      },
      failure: (f) {
        controller.dispose();
        return Result.failure(f);
      },
    );
  }

  /// Announces the hosted room again with [songName] (ROOM-09).
  Future<void> changeSong(String? songName) async {
    final room = state;
    if (room == null || room.role != RoomRole.host) return;
    await room.controller.updateAnnouncement(songName: songName);
    if (mounted) state = room.withSong(songName);
  }

  /// Starts looking for rooms, closing any room this device is in. The
  /// stream errors with a [NetworkFailure] when discovery is refused.
  Future<Result<Stream<DiscoveredRoom>, Failure>> search() async {
    await close();
    final controller = await _controllerForThisDevice();
    if (controller == null) {
      return Result.failure(StorageFailure(code: 'local_profile_read_failed'));
    }
    _searching = controller;
    return Result.success(controller.discoverRooms());
  }

  /// Asks [room] to let this device in with [code]. On success the room
  /// becomes the active one.
  Future<JoinOutcome> join(
    DiscoveredRoom room,
    String code, {
    required String displayName,
  }) async {
    final controller = _searching;
    if (controller == null) return JoinOutcome.connectionLost;
    final result =
        await controller.requestJoin(room.id, code, displayName: displayName);
    return result.when(
      success: (_) {
        if (!mounted || !identical(_searching, controller)) {
          return JoinOutcome.cancelled;
        }
        _searching = null;
        state = ActiveRoom(
          role: RoomRole.member,
          controller: controller,
          roomId: room.id,
          masterName: room.masterName,
          songName: room.songName,
        );
        return JoinOutcome.joined;
      },
      failure: joinOutcomeFor,
    );
  }

  /// "Cancelar pedido" (ROOM-30).
  Future<void> cancelJoin() async => _searching?.cancelJoin();

  /// Leaves or ends the active room and stops any search.
  Future<void> close() async {
    final room = state;
    if (room != null) {
      if (room.role == RoomRole.host) {
        await room.controller.endRoom();
      } else {
        await room.controller.leaveRoom();
      }
      room.controller.dispose();
      if (mounted) state = null;
    }
    final searching = _searching;
    _searching = null;
    if (searching != null) {
      await searching.cancelJoin();
      searching.dispose();
    }
  }

  Future<RoomSessionController?> _controllerForThisDevice() async {
    final profile = await _profiles.load();
    return profile.when(
      success: (p) => _newController(DeviceId(p.deviceId)),
      failure: (_) => null,
    );
  }

  @override
  void dispose() {
    final room = state;
    room?.controller.dispose();
    _searching?.dispose();
    super.dispose();
  }
}

final activeRoomProvider =
    StateNotifierProvider<ActiveRoomNotifier, ActiveRoom?>(
  (ref) => ActiveRoomNotifier(
    newController: ref.watch(roomControllerFactoryProvider),
    profiles: ref.watch(localProfileRepositoryProvider),
  ),
);
