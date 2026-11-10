import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/core/unit.dart';
import 'package:cantae/domain/entities/song_track.dart';
import 'package:cantae/domain/session/ids.dart';
import 'package:cantae/domain/transfer/chunk_planner.dart';

import '../session/room_application_message.dart';
import '../session/room_session_controller.dart';

/// Master-side orchestration for sending one track's file to one participant:
/// `TransferBegin -> ChunkData (bounded-retry) -> TransferComplete`
/// (design.md's `ChunkedFileSender`). Honors a caller-supplied resume offset
/// so a prior partial transfer is not restarted from zero (XFER-04 — the
/// automatic resume handshake itself is wired in T12).
///
/// SPEC_DEVIATION: design.md's interface sketch for `sendTrack` took only
/// `{track, to, resumeFromChunkIndex}` with no `songId`/hash parameter, but
/// `TransferBeginMessage` (T7) requires both a `songId` and a declared
/// SHA-256. `songId` is added as a required parameter; the SHA-256 is
/// computed here from the real file bytes (the sender always has the
/// authoritative file) rather than threaded in from outside.
/// Reason: the design's own wire message shape makes these two values
/// mandatory to send `TransferBeginMessage` at all; no behavior in the spec
/// ACs is changed by closing this gap.
class ChunkedFileSender {
  final RoomSessionController _controller;
  final int chunkSize;
  final int maxAttemptsPerChunk;
  final Duration ackTimeout;

  ChunkedFileSender({
    required RoomSessionController controller,
    this.chunkSize = 64 * 1024,
    this.maxAttemptsPerChunk = 5,
    this.ackTimeout = const Duration(seconds: 2),
  }) : _controller = controller;

  /// Sends [track]'s file to participant [to], starting from
  /// [resumeFromChunkIndex] (0 for a fresh transfer). Returns
  /// `Result.success(Unit())` once `TransferComplete` has been sent, or a
  /// `NetworkFailure(code: 'transfer.chunk-delivery-failed')` if any single
  /// chunk exhausts [maxAttemptsPerChunk] without an ACK.
  Future<Result<Unit, Failure>> sendTrack({
    required String songId,
    required SongTrack track,
    required ParticipantId to,
    int resumeFromChunkIndex = 0,
  }) async {
    final bytes = await File(track.filePath).readAsBytes();
    final totalSizeBytes = bytes.length;
    final sha256Declared = sha256.convert(bytes).toString();
    final totalChunks = ChunkPlanner.chunkCount(
      totalSizeBytes: totalSizeBytes,
      chunkSize: chunkSize,
    );

    await _controller.sendEnvelopeTo(
      to,
      TransferBeginMessage(
        songId: songId,
        trackId: track.id,
        totalSizeBytes: totalSizeBytes,
        sha256Declared: sha256Declared,
        chunkSize: chunkSize,
      ).encode(),
    );

    for (var chunkIndex = resumeFromChunkIndex;
        chunkIndex < totalChunks;
        chunkIndex++) {
      final start = chunkIndex * chunkSize;
      final end = min(start + chunkSize, totalSizeBytes);
      final chunkBytes = Uint8List.sublistView(bytes, start, end);

      final delivered = await _sendChunkWithRetry(
        to: to,
        trackId: track.id,
        chunkIndex: chunkIndex,
        chunkBytes: chunkBytes,
      );
      if (!delivered) {
        return Result.failure(
          NetworkFailure(code: 'transfer.chunk-delivery-failed'),
        );
      }
    }

    await _controller.sendEnvelopeTo(
      to,
      TransferCompleteMessage(trackId: track.id, accepted: true).encode(),
    );
    return const Result.success(Unit());
  }

  Future<bool> _sendChunkWithRetry({
    required ParticipantId to,
    required String trackId,
    required int chunkIndex,
    required Uint8List chunkBytes,
  }) async {
    for (var attempt = 0; attempt < maxAttemptsPerChunk; attempt++) {
      await _controller.sendEnvelopeTo(
        to,
        ChunkDataMessage(
          trackId: trackId,
          chunkIndex: chunkIndex,
          bytes: chunkBytes,
        ).encode(),
      );
      final acked = await _waitForAck(
        from: to,
        trackId: trackId,
        chunkIndex: chunkIndex,
      );
      if (acked) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _waitForAck({
    required ParticipantId from,
    required String trackId,
    required int chunkIndex,
  }) async {
    try {
      await _controller.applicationMessages
          .where((event) => event.$1 == from)
          .map((event) => RoomApplicationMessage.decode(event.$2))
          .firstWhere(
            (message) =>
                message is ChunkAckMessage &&
                message.trackId == trackId &&
                message.chunkIndex == chunkIndex,
          )
          .timeout(ackTimeout);
      return true;
    } on TimeoutException {
      return false;
    }
  }
}
