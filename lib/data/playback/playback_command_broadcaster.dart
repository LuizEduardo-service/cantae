import 'dart:async';
import 'dart:math';

import 'package:cantae/domain/playback/latency_estimator.dart';
import 'package:cantae/domain/session/ids.dart';
import 'package:cantae/domain/session/participant_session.dart';
import 'package:cantae/domain/session/room_session_snapshot.dart';

import '../session/room_application_message.dart';
import '../session/room_session_controller.dart';

/// Master-side orchestration for play/pause/stop/loop-reposition commands
/// (design.md's `PlaybackCommandBroadcaster`). On each command, probes
/// round-trip latency to every currently-connected participant
/// (`LatencyProbeMessage`/`LatencyProbeReplyMessage`), computes that
/// participant's scheduled epoch via `LatencyEstimator`
/// (`masterSendTime + estimatedOneWayDelay`, per spec's clock-sync
/// Assumption), and sends that participant its own latency-adjusted
/// `masterSendEpochMs` (SYNC-02, SYNC-04).
///
/// SPEC_DEVIATION: design.md's interface sketch used `play(SongId songId)`,
/// but the domain has no `SongId` value type — `Song.id` is a plain
/// `String` (see `lib/domain/entities/song.dart`). `play` takes a `String`
/// instead. No behavior changes; this only matches an existing type that
/// design.md assumed without one being defined.
class PlaybackCommandBroadcaster {
  final RoomSessionController _controller;
  final DateTime Function() _now;
  final Duration probeTimeout;
  final Random _random;
  RoomSessionSnapshot? _latestSnapshot;
  late final StreamSubscription<RoomSessionSnapshot> _snapshotSubscription;
  int _probeCounter = 0;

  PlaybackCommandBroadcaster({
    required RoomSessionController controller,
    DateTime Function()? now,
    this.probeTimeout = const Duration(milliseconds: 500),
    Random? random,
  })  : _controller = controller,
        _now = now ?? DateTime.now,
        _random = random ?? Random.secure() {
    // Seed synchronously from whatever room state already exists: a
    // broadcast stream never replays past events to a new listener, so a
    // broadcaster constructed after participants are already connected
    // (e.g. the master's post-join playback-command wiring, or this
    // controller simply having been alive for a while) would otherwise sit
    // with an empty participant list — and silently broadcast to nobody —
    // until the next unrelated snapshot event happens to fire.
    _latestSnapshot = _controller.currentSnapshot;
    _snapshotSubscription = _controller.snapshots.listen((snapshot) {
      _latestSnapshot = snapshot;
    });
  }

  Future<void> play(String songId) => _broadcastCommand(
        (epoch) => PlayCommandMessage(songId: songId, masterSendEpochMs: epoch),
      );

  Future<void> pause() => _broadcastCommand(
        (epoch) => PauseCommandMessage(masterSendEpochMs: epoch),
      );

  Future<void> stop() => _broadcastCommand(
        (epoch) => StopCommandMessage(masterSendEpochMs: epoch),
      );

  Future<void> repositionToLoopStart() => _broadcastCommand(
        (epoch) => LoopRepositionMessage(masterSendEpochMs: epoch),
      );

  Future<void> _broadcastCommand(
    RoomApplicationMessage Function(int scheduledEpochMs) buildMessage,
  ) async {
    final masterSendTime = _now().millisecondsSinceEpoch;
    final connected = _connectedParticipantIds();
    for (final participantId in connected) {
      final estimatedDelayMs = await _probeLatency(participantId);
      final scheduledEpoch = masterSendTime + estimatedDelayMs;
      await _controller.sendEnvelopeTo(
        participantId,
        buildMessage(scheduledEpoch).encode(),
        requiresMasterRole: true,
      );
    }
  }

  Future<int> _probeLatency(ParticipantId participant) async {
    final probeId = 'probe-${_probeCounter++}-${_random.nextInt(1 << 32)}';
    final sentAt = _now().millisecondsSinceEpoch;

    final replyFuture = _awaitProbeReply(participant, probeId);

    await _controller.sendEnvelopeTo(
      participant,
      LatencyProbeMessage(probeId: probeId, masterSendEpochMs: sentAt).encode(),
    );

    await replyFuture;
    final receivedBackAt = _now().millisecondsSinceEpoch;

    return LatencyEstimator.estimateOneWayDelayMs(
      sentAtEpochMs: sentAt,
      echoedAtEpochMs: sentAt,
      receivedBackAtEpochMs: receivedBackAt,
    );
  }

  /// Waits (bounded by [probeTimeout]) for [participant]'s
  /// `LatencyProbeReplyMessage` matching [probeId]. A timeout is treated as
  /// "no measurement" — the caller still proceeds (spec Edge Case: no
  /// fallback mode exists, the 100 ms target is a measured bar, not a
  /// guaranteed clamp).
  Future<void> _awaitProbeReply(ParticipantId participant, String probeId) async {
    try {
      await _controller.applicationMessages
          .where((event) => event.$1 == participant)
          .map((event) => RoomApplicationMessage.decode(event.$2))
          .firstWhere(
            (message) =>
                message is LatencyProbeReplyMessage &&
                message.probeId == probeId,
          )
          .timeout(probeTimeout);
    } on TimeoutException {
      // No reply within the probe window — proceed with whatever elapsed
      // time has already passed as the (degraded) delay estimate.
    }
  }

  List<ParticipantId> _connectedParticipantIds() {
    final snapshot = _latestSnapshot;
    if (snapshot == null) {
      return const [];
    }
    return snapshot.participants
        .where((p) => p.state == ParticipantState.connected)
        .map((p) => p.id)
        .toList();
  }

  void dispose() {
    _snapshotSubscription.cancel();
  }
}
