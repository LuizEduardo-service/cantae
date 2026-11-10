import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/session/ids.dart';
import 'package:cantae/domain/transfer/file_transfer_state.dart';

void main() {
  FileTransferState initial() => FileTransferState.initial(
        trackId: 'track-1',
        participant: const ParticipantId('participant-1'),
        totalChunks: 3,
      );

  group('FileTransferState.advance — valid transitions', () {
    test('pending -> inProgress on TransferStarted', () {
      final result = initial().advance(const TransferStarted());
      expect(result.isSuccess, isTrue);
      result.when(
        success: (state) => expect(state.phase, equals(TransferPhase.inProgress)),
        failure: (_) => fail('expected success'),
      );
    });

    test('inProgress -> inProgress on ChunkAcked, updates lastAckedChunkIndex', () {
      final inProgress =
          initial().advance(const TransferStarted()).when(
                success: (s) => s,
                failure: (_) => throw StateError('setup failed'),
              );
      final result = inProgress.advance(const ChunkAcked(1));
      expect(result.isSuccess, isTrue);
      result.when(
        success: (state) {
          expect(state.phase, equals(TransferPhase.inProgress));
          expect(state.lastAckedChunkIndex, equals(1));
        },
        failure: (_) => fail('expected success'),
      );
    });

    test('inProgress -> validating on AllChunksReceived', () {
      final inProgress = initial().advance(const TransferStarted()).when(
            success: (s) => s,
            failure: (_) => throw StateError('setup failed'),
          );
      final result = inProgress.advance(const AllChunksReceived());
      expect(result.isSuccess, isTrue);
      result.when(
        success: (state) => expect(state.phase, equals(TransferPhase.validating)),
        failure: (_) => fail('expected success'),
      );
    });

    test(
        'inProgress -> failed on ChunkDeliveryFailed, carries transfer.chunk-delivery-failed (XFER-03)',
        () {
      final inProgress = initial().advance(const TransferStarted()).when(
            success: (s) => s,
            failure: (_) => throw StateError('setup failed'),
          );
      final result = inProgress.advance(const ChunkDeliveryFailed());
      expect(result.isSuccess, isTrue);
      result.when(
        success: (state) {
          expect(state.phase, equals(TransferPhase.failed));
          expect(state.failureCode, equals('transfer.chunk-delivery-failed'));
        },
        failure: (_) => fail('expected success'),
      );
    });

    test(
        'inProgress -> failed on InsufficientStorageDetected, carries transfer.insufficient-storage (XFER-10)',
        () {
      final inProgress = initial().advance(const TransferStarted()).when(
            success: (s) => s,
            failure: (_) => throw StateError('setup failed'),
          );
      final result = inProgress.advance(const InsufficientStorageDetected());
      expect(result.isSuccess, isTrue);
      result.when(
        success: (state) {
          expect(state.phase, equals(TransferPhase.failed));
          expect(state.failureCode, equals('transfer.insufficient-storage'));
        },
        failure: (_) => fail('expected success'),
      );
    });

    test('validating -> available on HashValidated (XFER-05/06)', () {
      final validating = initial()
          .advance(const TransferStarted())
          .when(success: (s) => s, failure: (_) => throw StateError('setup'))
          .advance(const AllChunksReceived())
          .when(success: (s) => s, failure: (_) => throw StateError('setup'));
      final result = validating.advance(const HashValidated());
      expect(result.isSuccess, isTrue);
      result.when(
        success: (state) => expect(state.phase, equals(TransferPhase.available)),
        failure: (_) => fail('expected success'),
      );
    });

    test(
        'validating -> failed on HashMismatched, carries transfer.hash-mismatch, never reaches available (XFER-06)',
        () {
      final validating = initial()
          .advance(const TransferStarted())
          .when(success: (s) => s, failure: (_) => throw StateError('setup'))
          .advance(const AllChunksReceived())
          .when(success: (s) => s, failure: (_) => throw StateError('setup'));
      final result = validating.advance(const HashMismatched());
      expect(result.isSuccess, isTrue);
      result.when(
        success: (state) {
          expect(state.phase, equals(TransferPhase.failed));
          expect(state.failureCode, equals('transfer.hash-mismatch'));
        },
        failure: (_) => fail('expected success'),
      );
    });

    test(
        'validating -> failed on InsufficientStorageDetected, carries transfer.insufficient-storage (XFER-10)',
        () {
      final validating = initial()
          .advance(const TransferStarted())
          .when(success: (s) => s, failure: (_) => throw StateError('setup'))
          .advance(const AllChunksReceived())
          .when(success: (s) => s, failure: (_) => throw StateError('setup'));
      final result = validating.advance(const InsufficientStorageDetected());
      expect(result.isSuccess, isTrue);
      result.when(
        success: (state) {
          expect(state.phase, equals(TransferPhase.failed));
          expect(state.failureCode, equals('transfer.insufficient-storage'));
        },
        failure: (_) => fail('expected success'),
      );
    });
  });

  group('FileTransferState.advance — invalid transitions rejected per state', () {
    test('pending rejects HashValidated (out-of-order event)', () {
      final result = initial().advance(const HashValidated());
      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) {
          expect(f, isA<ValidationFailure>());
          expect(f.code, equals('transfer.invalid-transition'));
        },
      );
    });

    test('inProgress rejects HashValidated (must pass through validating)', () {
      final inProgress = initial().advance(const TransferStarted()).when(
            success: (s) => s,
            failure: (_) => throw StateError('setup failed'),
          );
      final result = inProgress.advance(const HashValidated());
      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) => expect(f.code, equals('transfer.invalid-transition')),
      );
    });

    test('validating rejects ChunkAcked (chunks are already fully received)', () {
      final validating = initial()
          .advance(const TransferStarted())
          .when(success: (s) => s, failure: (_) => throw StateError('setup'))
          .advance(const AllChunksReceived())
          .when(success: (s) => s, failure: (_) => throw StateError('setup'));
      final result = validating.advance(const ChunkAcked(2));
      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) => expect(f.code, equals('transfer.invalid-transition')),
      );
    });

    test('available (terminal) rejects any further event', () {
      final available = initial()
          .advance(const TransferStarted())
          .when(success: (s) => s, failure: (_) => throw StateError('setup'))
          .advance(const AllChunksReceived())
          .when(success: (s) => s, failure: (_) => throw StateError('setup'))
          .advance(const HashValidated())
          .when(success: (s) => s, failure: (_) => throw StateError('setup'));
      final result = available.advance(const TransferStarted());
      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) => expect(f.code, equals('transfer.invalid-transition')),
      );
    });

    test('failed (terminal) rejects any further event', () {
      final failed = initial().advance(const TransferStarted()).when(
            success: (s) => s,
            failure: (_) => throw StateError('setup failed'),
          ).advance(const ChunkDeliveryFailed()).when(
            success: (s) => s,
            failure: (_) => throw StateError('setup failed'),
          );
      final result = failed.advance(const TransferStarted());
      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) => expect(f.code, equals('transfer.invalid-transition')),
      );
    });
  });
}
