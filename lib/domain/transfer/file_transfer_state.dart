import '../core/failures.dart';
import '../core/result.dart';
import '../session/ids.dart';

enum TransferPhase { pending, inProgress, validating, available, failed }

sealed class TransferEvent {
  const TransferEvent();
}

final class TransferStarted extends TransferEvent {
  const TransferStarted();
}

final class ChunkAcked extends TransferEvent {
  final int chunkIndex;
  const ChunkAcked(this.chunkIndex);
}

final class AllChunksReceived extends TransferEvent {
  const AllChunksReceived();
}

final class HashValidated extends TransferEvent {
  const HashValidated();
}

final class HashMismatched extends TransferEvent {
  const HashMismatched();
}

final class ChunkDeliveryFailed extends TransferEvent {
  const ChunkDeliveryFailed();
}

final class InsufficientStorageDetected extends TransferEvent {
  const InsufficientStorageDetected();
}

final class FileTransferState {
  final String trackId;
  final ParticipantId participant;
  final TransferPhase phase;
  final int lastAckedChunkIndex; // -1 = none yet
  final int totalChunks;
  final String? failureCode;

  const FileTransferState({
    required this.trackId,
    required this.participant,
    required this.phase,
    required this.lastAckedChunkIndex,
    required this.totalChunks,
    this.failureCode,
  });

  factory FileTransferState.initial({
    required String trackId,
    required ParticipantId participant,
    required int totalChunks,
  }) {
    return FileTransferState(
      trackId: trackId,
      participant: participant,
      phase: TransferPhase.pending,
      lastAckedChunkIndex: -1,
      totalChunks: totalChunks,
    );
  }

  Result<FileTransferState, Failure> advance(TransferEvent event) {
    switch (phase) {
      case TransferPhase.pending:
        if (event is TransferStarted) {
          return Result.success(_copyWith(phase: TransferPhase.inProgress));
        }
        return _invalidTransition();

      case TransferPhase.inProgress:
        if (event is ChunkAcked) {
          return Result.success(
            _copyWith(lastAckedChunkIndex: event.chunkIndex),
          );
        }
        if (event is AllChunksReceived) {
          return Result.success(_copyWith(phase: TransferPhase.validating));
        }
        if (event is ChunkDeliveryFailed) {
          return Result.success(_copyWith(
            phase: TransferPhase.failed,
            failureCode: 'transfer.chunk-delivery-failed',
          ));
        }
        if (event is InsufficientStorageDetected) {
          return Result.success(_copyWith(
            phase: TransferPhase.failed,
            failureCode: 'transfer.insufficient-storage',
          ));
        }
        return _invalidTransition();

      case TransferPhase.validating:
        if (event is HashValidated) {
          return Result.success(_copyWith(phase: TransferPhase.available));
        }
        if (event is HashMismatched) {
          return Result.success(_copyWith(
            phase: TransferPhase.failed,
            failureCode: 'transfer.hash-mismatch',
          ));
        }
        if (event is InsufficientStorageDetected) {
          return Result.success(_copyWith(
            phase: TransferPhase.failed,
            failureCode: 'transfer.insufficient-storage',
          ));
        }
        return _invalidTransition();

      case TransferPhase.available:
      case TransferPhase.failed:
        return _invalidTransition();
    }
  }

  Result<FileTransferState, Failure> _invalidTransition() {
    return Result.failure(
      ValidationFailure(code: 'transfer.invalid-transition'),
    );
  }

  FileTransferState _copyWith({
    TransferPhase? phase,
    int? lastAckedChunkIndex,
    String? failureCode,
  }) {
    return FileTransferState(
      trackId: trackId,
      participant: participant,
      phase: phase ?? this.phase,
      lastAckedChunkIndex: lastAckedChunkIndex ?? this.lastAckedChunkIndex,
      totalChunks: totalChunks,
      failureCode: failureCode ?? this.failureCode,
    );
  }
}
