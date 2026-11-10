import 'dart:async';
import 'dart:io';

import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/core/unit.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/entities/song_track.dart';
import 'package:cantae/domain/session/participant_session.dart';
import 'package:cantae/domain/session/room_session_snapshot.dart';
import 'package:cantae/domain/transfer/chunk_planner.dart';

import 'chunked_file_sender.dart';
import '../session/room_session_controller.dart';

/// Progress of one `syncSongToRoom` run, reported per (track, participant)
/// send attempt.
class SongSyncProgress {
  final String songId;
  final String trackId;
  final bool success;
  final String? failureCode;

  const SongSyncProgress({
    required this.songId,
    required this.trackId,
    required this.success,
    this.failureCode,
  });
}

/// Presentation-facing entry point for pushing a song's files to every
/// connected participant in the room (design.md's `SongSyncCoordinator`).
/// Enforces: every track to every connected participant (XFER-01), the
/// 100 MB per-track size cap checked before any chunk is sent (Edge Case),
/// and one song mid-transfer per room at a time — a second call queues
/// rather than interleaving with the first (XFER-08).
///
/// Must be constructed early in the controller's lifetime (e.g. right after
/// `createRoom()`), since it learns the current participant list by
/// subscribing to `controller.snapshots` — a broadcast stream with no
/// "current value" accessor, so snapshot updates emitted before this
/// coordinator exists are not seen.
class SongSyncCoordinator {
  final RoomSessionController _controller;
  final ChunkedFileSender _sender;
  final _progressController = StreamController<SongSyncProgress>.broadcast();
  late final StreamSubscription<RoomSessionSnapshot> _snapshotSubscription;
  RoomSessionSnapshot? _latestSnapshot;
  Future<Result<Unit, Failure>> _queueTail =
      Future.value(const Result.success(Unit()));

  SongSyncCoordinator({
    required RoomSessionController controller,
    required ChunkedFileSender sender,
  })  : _controller = controller,
        _sender = sender {
    _snapshotSubscription = _controller.snapshots.listen((snapshot) {
      _latestSnapshot = snapshot;
    });
  }

  Stream<SongSyncProgress> get progress => _progressController.stream;

  /// Sends every track of [song] (naipes + playback track) to every
  /// currently-connected participant. If a sync is already in flight, this
  /// call queues behind it instead of interleaving chunk traffic.
  Future<Result<Unit, Failure>> syncSongToRoom(Song song) {
    final scheduled = _queueTail.then((_) => _runSync(song));
    _queueTail = scheduled;
    return scheduled;
  }

  Future<Result<Unit, Failure>> _runSync(Song song) async {
    final tracks = <SongTrack>[
      ...song.tracks,
      if (song.playbackTrack != null) song.playbackTrack!,
    ];

    for (final track in tracks) {
      final sizeBytes = await File(track.filePath).length();
      if (ChunkPlanner.exceedsMaxSize(sizeBytes)) {
        return Result.failure(
          ValidationFailure(code: 'transfer.file-too-large'),
        );
      }
    }

    final connectedParticipants = _latestSnapshot?.participants
            .where((p) => p.state == ParticipantState.connected) ??
        const <ParticipantSession>[];

    for (final participant in connectedParticipants) {
      for (final track in tracks) {
        final result = await _sender.sendTrack(
          songId: song.id,
          track: track,
          to: participant.id,
        );
        _progressController.add(SongSyncProgress(
          songId: song.id,
          trackId: track.id,
          success: result.isSuccess,
          failureCode: result.when(
            success: (_) => null,
            failure: (f) => f.code,
          ),
        ));
        if (result.isFailure) {
          return result;
        }
      }
    }

    return const Result.success(Unit());
  }

  void dispose() {
    _snapshotSubscription.cancel();
    unawaited(_progressController.close());
  }
}
