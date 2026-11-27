import 'dart:async';

import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/core/unit.dart';
import 'package:cantae/domain/entities/local_profile.dart';
import 'package:cantae/domain/repositories/local_profile_repository.dart';
import 'package:cantae/domain/session/ids.dart';
import 'package:cantae/domain/session/room_discovery.dart';

/// The Wi‑Fi of a test: rooms announced by one device are seen by every
/// [InMemoryRoomDiscovery] on the same [RoomBus], like a real scan
/// (rooms already announced show up first).
class RoomBus {
  final _events = StreamController<DiscoveredRoom>.broadcast();
  final _current = <RoomId, DiscoveredRoom>{};

  void announce(DiscoveredRoom room) {
    if (room.available) {
      _current[room.id] = room;
    } else {
      _current.remove(room.id);
    }
    _events.add(room);
  }

  Stream<DiscoveredRoom> scan() async* {
    yield* Stream.fromIterable(_current.values.toList());
    yield* _events.stream;
  }

  Future<void> close() => _events.close();
}

/// One device's mDNS on a [RoomBus].
class InMemoryRoomDiscovery implements RoomDiscovery {
  InMemoryRoomDiscovery(this.bus);

  final RoomBus bus;
  Result<Unit, NetworkFailure> advertiseResult = const Result.success(Unit());

  /// When set, discovery fails with this failure on the stream.
  NetworkFailure? discoverError;
  final announcements = <RoomAnnouncement>[];
  var stops = 0;
  RoomId? _advertised;

  @override
  Future<Result<Unit, NetworkFailure>> advertise(
    RoomId id,
    int port,
    RoomAnnouncement announcement,
  ) async {
    announcements.add(announcement);
    if (advertiseResult.isSuccess) {
      _advertised = id;
      bus.announce(DiscoveredRoom(
        id: id,
        host: '127.0.0.1',
        port: port,
        masterName: announcement.masterName,
        songName: announcement.songName,
        protocolVersion: announcement.protocolVersion,
      ));
    }
    return advertiseResult;
  }

  @override
  Stream<DiscoveredRoom> discover() {
    final error = discoverError;
    if (error != null) return Stream.error(error);
    return bus.scan();
  }

  @override
  Future<void> stopAdvertising() async {
    stops++;
    final id = _advertised;
    _advertised = null;
    if (id != null) {
      bus.announce(DiscoveredRoom(id: id, host: '', port: 0, available: false));
    }
  }
}

/// A device profile kept in memory.
class InMemoryLocalProfiles implements LocalProfileRepository {
  InMemoryLocalProfiles(this.deviceId, {this.displayName});

  final String deviceId;
  String? displayName;
  StorageFailure? failure;

  @override
  Future<Result<LocalProfile, StorageFailure>> load() async => _result();

  @override
  Future<Result<LocalProfile, StorageFailure>> saveDisplayName(
    String name,
  ) async {
    if (failure == null) displayName = name;
    return _result();
  }

  Result<LocalProfile, StorageFailure> _result() {
    final f = failure;
    if (f != null) return Result.failure(f);
    return Result.success(
      LocalProfile(deviceId: deviceId, displayName: displayName),
    );
  }
}
