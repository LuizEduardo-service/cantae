import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cantae/domain/transfer/chunk_planner.dart';
import 'package:cantae/domain/transfer/file_transfer_state.dart';

import 'library_storage_paths.dart';
import '../session/room_application_message.dart';
import '../session/room_session_controller.dart';

/// Writes one chunk's bytes to the track's `.partial` file at the correct
/// offset. Overridable in tests to simulate a write failure (e.g. disk full)
/// without needing a real full-disk environment.
typedef ChunkWriter = Future<void> Function({
  required String partialFilePath,
  required int chunkIndex,
  required int chunkSize,
  required Uint8List bytes,
});

Future<void> _defaultChunkWriter({
  required String partialFilePath,
  required int chunkIndex,
  required int chunkSize,
  required Uint8List bytes,
}) async {
  final file = File(partialFilePath);
  if (!await file.exists()) {
    await file.create(recursive: true);
  }
  final raf = await file.open(mode: FileMode.writeOnlyAppend);
  try {
    await raf.setPosition(chunkIndex * chunkSize);
    await raf.writeFrom(bytes);
  } finally {
    await raf.close();
  }
}

/// Progress/outcome of one `receiveTrack` run, mirroring `FileTransferState`'s
/// phase for presentation-layer consumption.
class TransferProgress {
  final TransferPhase phase;
  final int lastAckedChunkIndex;
  final String? failureCode;

  const TransferProgress({
    required this.phase,
    required this.lastAckedChunkIndex,
    this.failureCode,
  });
}

enum _AttemptOutcome { allChunksReceived, storageFailure }

/// Participant-side orchestration for one track's transfer (design.md's
/// `ChunkedFileReceiver`): opens a `.partial` file on `TransferBeginMessage`,
/// writes + ACKs each `ChunkDataMessage`, and on receiving every chunk
/// computes the SHA-256 of the reassembled file — promoting it into the
/// content-addressed library path on a match, discarding and retrying
/// (bounded to [maxWholeTrackRetries] whole-track attempts) on a mismatch.
///
/// SPEC_DEVIATION: design.md's `receiveTrack` signature omits `chunkSize`,
/// but chunk boundaries cannot be computed without it. This implementation
/// learns `chunkSize` from the sender's own `TransferBeginMessage` for the
/// matching `trackId` rather than requiring the caller to already know it —
/// consistent with the design's narrative ("on `TransferBeginMessage`,
/// opens a `.partial` file"), which assumes the message is received first.
class ChunkedFileReceiver {
  final RoomSessionController _controller;
  final Directory _storageRoot;
  final int maxWholeTrackRetries;
  final ChunkWriter _writeChunk;

  ChunkedFileReceiver({
    required RoomSessionController controller,
    required Directory storageRoot,
    this.maxWholeTrackRetries = 2,
    ChunkWriter? writeChunk,
    Future<bool> Function(String path)? fileExists,
  })  : _controller = controller,
        _storageRoot = storageRoot,
        _writeChunk = writeChunk ?? _defaultChunkWriter,
        _fileExists = fileExists ?? _defaultFileExists;

  /// The dedup check (XFER-07). Injectable so a test can hold it while
  /// messages arrive.
  final Future<bool> Function(String path) _fileExists;

  static Future<bool> _defaultFileExists(String path) => File(path).exists();

  /// Receives [trackId]'s file. If a file already exists at the
  /// content-addressed final path for [expectedSha256], the transfer is
  /// skipped entirely (dedup, XFER-07) — no chunk is ever written.
  ///
  /// Subscribes to the controller's `applicationMessages` synchronously,
  /// before this method returns, so no chunk sent immediately after the
  /// caller starts listening can ever be missed.
  Stream<TransferProgress> receiveTrack({
    required String trackId,
    required String expectedSha256,
    required int totalSizeBytes,
    String extension = 'bin',
  }) {
    final progress = StreamController<TransferProgress>();
    final partialPath = _partialPath(trackId);
    final finalPath = _finalPath(expectedSha256, extension);

    int? chunkSize;
    int? totalChunks;
    var receivedChunks = <int>{};
    Completer<_AttemptOutcome>? attemptCompleter;

    // The underlying socket's flush() rejects a second concurrent call
    // ("StreamSink is bound to a stream"). The Begin-handler's ACK and a
    // ChunkData-handler's ACK can otherwise overlap, because Dart delivers
    // the next stream event to an async onData callback without waiting for
    // the previous invocation's Future to complete. Routing every outbound
    // send through this chain serializes them.
    var sendQueue = Future<void>.value();
    Future<void> sendSerialized(Uint8List payload) {
      final result = sendQueue.then((_) => _controller.sendEnvelope(payload));
      sendQueue = result.then((_) {}, onError: (_) {});
      return result;
    }

    final subscription = _controller.applicationMessages
        .map((event) => RoomApplicationMessage.decode(event.$2))
        .listen((message) async {
      final completer = attemptCompleter;
      if (completer == null || completer.isCompleted) {
        return;
      }

      if (message is TransferBeginMessage && message.trackId == trackId) {
        if (chunkSize == null) {
          chunkSize = message.chunkSize;
          totalChunks = ChunkPlanner.chunkCount(
            totalSizeBytes: totalSizeBytes,
            chunkSize: chunkSize!,
          );
        }
        // T12: report the current resume point back on a resend after a
        // reconnect (some chunks already written) — the sender treats this
        // as the resume signal. A genuinely fresh transfer stays silent
        // here: `ChunkAckMessage.chunkIndex` is wire-encoded as an unsigned
        // 32-bit int, so there is no in-band way to signal "-1, nothing yet"
        // over the wire; the sender's own probe timeout already assumes a
        // fresh start (resumeFromChunkIndex 0) when no reply arrives.
        if (receivedChunks.isNotEmpty) {
          final lastAcked = receivedChunks.reduce((a, b) => a > b ? a : b);
          await sendSerialized(
            ChunkAckMessage(trackId: trackId, chunkIndex: lastAcked).encode(),
          );
        }
        if (totalChunks == 0 && !completer.isCompleted) {
          completer.complete(_AttemptOutcome.allChunksReceived);
        }
        return;
      }

      if (message is ChunkDataMessage &&
          message.trackId == trackId &&
          chunkSize != null) {
        if (receivedChunks.contains(message.chunkIndex)) {
          return; // already written (e.g. a retransmitted chunk).
        }
        try {
          await _writeChunk(
            partialFilePath: partialPath,
            chunkIndex: message.chunkIndex,
            chunkSize: chunkSize!,
            bytes: message.bytes,
          );
        } catch (_) {
          completer.complete(_AttemptOutcome.storageFailure);
          return;
        }
        receivedChunks.add(message.chunkIndex);
        progress.add(TransferProgress(
          phase: TransferPhase.inProgress,
          lastAckedChunkIndex: message.chunkIndex,
        ));
        await sendSerialized(
          ChunkAckMessage(trackId: trackId, chunkIndex: message.chunkIndex)
              .encode(),
        );
        if (receivedChunks.length == totalChunks) {
          completer.complete(_AttemptOutcome.allChunksReceived);
        }
      }
    });

    // The first attempt accepts messages right away: a TransferBegin that
    // arrives while the dedup check below is still on disk must not be
    // dropped, or the transfer stalls (flaky-tests regression).
    attemptCompleter = Completer<_AttemptOutcome>();

    unawaited(() async {
      if (await _fileExists(finalPath)) {
        await subscription.cancel();
        // Chunks written while the check ran are not needed.
        final partial = File(partialPath);
        if (await partial.exists()) await partial.delete();
        progress.add(const TransferProgress(
          phase: TransferPhase.available,
          lastAckedChunkIndex: -1,
        ));
        await progress.close();
        return;
      }

      for (var attempt = 0; attempt <= maxWholeTrackRetries; attempt++) {
        if (attempt > 0) {
          chunkSize = null;
          totalChunks = null;
          receivedChunks = <int>{};
          attemptCompleter = Completer<_AttemptOutcome>();
        }
        final outcome = await attemptCompleter!.future;

        if (outcome == _AttemptOutcome.storageFailure) {
          await subscription.cancel();
          progress.add(const TransferProgress(
            phase: TransferPhase.failed,
            lastAckedChunkIndex: -1,
            failureCode: 'transfer.insufficient-storage',
          ));
          await progress.close();
          return;
        }

        final partialFile = File(partialPath);
        final bytes =
            totalChunks == 0 ? Uint8List(0) : await partialFile.readAsBytes();
        final actualSha256 = sha256.convert(bytes).toString();

        if (actualSha256 == expectedSha256) {
          if (totalChunks == 0) {
            await File(finalPath).create(recursive: true);
          } else {
            await partialFile.rename(finalPath);
          }
          await subscription.cancel();
          progress.add(const TransferProgress(
            phase: TransferPhase.available,
            lastAckedChunkIndex: -1,
          ));
          await progress.close();
          return;
        }

        if (await partialFile.exists()) {
          await partialFile.delete();
        }
        // Hash mismatch: loop continues to the next whole-track attempt.
      }

      await subscription.cancel();
      progress.add(const TransferProgress(
        phase: TransferPhase.failed,
        lastAckedChunkIndex: -1,
        failureCode: 'transfer.hash-mismatch',
      ));
      await progress.close();
    }());

    return progress.stream;
  }

  String _finalPath(String expectedSha256, String extension) =>
      LibraryStoragePaths.trackFilePath(
        root: _storageRoot,
        sha256: expectedSha256,
        extension: extension,
      );

  String _partialPath(String trackId) =>
      '${_storageRoot.path}${Platform.pathSeparator}$trackId.partial';
}
