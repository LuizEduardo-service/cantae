import 'dart:async';

import 'package:cantae/domain/audio/audio_playback_engine.dart';
import 'package:cantae/domain/playback/room_playback_snapshot.dart';

import '../session/room_application_message.dart';
import '../session/room_session_controller.dart';

/// Per-device playback command handler (design.md's `PlaybackCommandHandler`).
/// Listens on `applicationMessages` for playback commands broadcast by
/// `PlaybackCommandBroadcaster`, schedules the matching `AudioPlaybackEngine`
/// call at the message's target epoch, and maintains a `RoomPlaybackSnapshot`
/// — entering `waiting` instead of calling the engine when a
/// `PlaybackSnapshotMessage` reports the room is already `playing` (late
/// join, SYNC-06).
///
/// Tech Decision (design.md): this handler trusts the envelope-layer
/// `requiresMasterRole` gate and does not re-derive role from message
/// content — [handleApplicationMessage] is the single entry point for any
/// decoded message and performs no independent role/sender check of its
/// own; in production it is fed exclusively by `controller.applicationMessages`
/// (which only emits after that gate passes), but it has no code path that
/// would reject a message handed to it directly.
class PlaybackCommandHandler {
  final AudioPlaybackEngine _engine;
  final DateTime Function() _now;
  final _snapshotsController =
      StreamController<RoomPlaybackSnapshot>.broadcast();
  RoomPlaybackSnapshot _current = const RoomPlaybackSnapshot(
    activeSongId: null,
    phase: PlaybackPhase.idle,
    scheduledStartAt: null,
  );
  StreamSubscription<dynamic>? _subscription;

  PlaybackCommandHandler({
    required AudioPlaybackEngine engine,
    RoomSessionController? controller,
    DateTime Function()? now,
  })  : _engine = engine,
        _now = now ?? DateTime.now {
    if (controller != null) {
      _subscription = controller.applicationMessages
          .map((event) => RoomApplicationMessage.decode(event.$2))
          .listen(handleApplicationMessage);
    }
  }

  Stream<RoomPlaybackSnapshot> get snapshots => _snapshotsController.stream;

  RoomPlaybackSnapshot get current => _current;

  /// Processes one decoded application message. Public so it can be driven
  /// directly in tests without a `RoomSessionController` — see the class
  /// doc's Tech Decision note: this method performs no role check of its
  /// own, by design.
  void handleApplicationMessage(RoomApplicationMessage message) {
    if (message is PlaybackSnapshotMessage) {
      _handleSnapshotMessage(message);
      return;
    }
    if (message is PlayCommandMessage) {
      _scheduleAt(message.masterSendEpochMs, () async {
        await _engine.playAt(
          DateTime.fromMillisecondsSinceEpoch(message.masterSendEpochMs),
        );
        _emit(PlaybackPhase.playing, activeSongId: message.songId);
      }, activeSongId: message.songId);
      return;
    }
    if (message is PauseCommandMessage) {
      _scheduleAt(message.masterSendEpochMs, () async {
        await _engine.pause();
        _emit(PlaybackPhase.paused);
      });
      return;
    }
    if (message is StopCommandMessage) {
      _scheduleAt(message.masterSendEpochMs, () async {
        await _engine.stop();
        _emit(PlaybackPhase.idle, activeSongId: null);
      });
      return;
    }
    if (message is LoopRepositionMessage) {
      _scheduleAt(message.masterSendEpochMs, () async {
        await _engine.seekAllTo(0);
        _emit(PlaybackPhase.playing);
      });
      return;
    }
  }

  void _handleSnapshotMessage(PlaybackSnapshotMessage message) {
    if (message.state == 'playing') {
      // SYNC-06: a (re)connecting device must stay silent — no engine call
      // — until the next PlayCommand/LoopReposition, instead of cutting in
      // mid-stream.
      _emit(PlaybackPhase.waiting, activeSongId: message.songId);
      return;
    }
    _emit(PlaybackPhase.idle, activeSongId: message.songId);
  }

  void _scheduleAt(
    int targetEpochMs,
    Future<void> Function() onFire, {
    Object? activeSongId = _unset,
  }) {
    final targetTime = DateTime.fromMillisecondsSinceEpoch(targetEpochMs);
    final delay = targetTime.difference(_now());
    _emit(
      PlaybackPhase.scheduled,
      activeSongId: activeSongId,
      scheduledStartAt: targetTime,
    );
    Timer(delay.isNegative ? Duration.zero : delay, onFire);
  }

  static const _unset = Object();

  void _emit(
    PlaybackPhase phase, {
    Object? activeSongId = _unset,
    DateTime? scheduledStartAt,
  }) {
    _current = RoomPlaybackSnapshot(
      activeSongId: activeSongId == _unset
          ? _current.activeSongId
          : activeSongId as String?,
      phase: phase,
      scheduledStartAt: scheduledStartAt,
    );
    _snapshotsController.add(_current);
  }

  void dispose() {
    _subscription?.cancel();
    unawaited(_snapshotsController.close());
  }
}
