import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/core/unit.dart';
import 'package:cantae/domain/session/envelope.dart';
import 'package:cantae/domain/session/envelope_authenticator.dart';
import 'package:cantae/domain/session/handshake_service.dart';
import 'package:cantae/domain/session/ids.dart';
import 'package:cantae/domain/session/room.dart';
import 'package:cantae/domain/session/room_discovery.dart';
import 'package:cantae/domain/session/room_session_snapshot.dart';
import 'package:cantae/domain/session/room_session_state_machine.dart';
import 'package:cantae/domain/session/session_transport.dart';

import 'frame_codec.dart';
import 'session_wire_message.dart';

class RoomSessionController {
  final SessionTransport _transport;
  final RoomDiscovery _discovery;
  final HandshakeService _handshakeService;
  final EnvelopeAuthenticator _authenticator;
  final DeviceId _selfDeviceId;
  final DateTime Function() _now;
  final Duration _tickInterval;
  final Random _random;

  RoomSessionStateMachine? _stateMachine;
  Timer? _tickTimer;

  final _snapshotsController =
      StreamController<RoomSessionSnapshot>.broadcast();
  final Map<RoomId, DiscoveredRoom> _knownRooms = {};
  final Map<ParticipantId, FrameReassembler> _reassemblers = {};

  // Master side: connection handle <-> admitted domain participant id.
  final Map<ParticipantId, ParticipantId> _connectionByParticipant = {};
  final Map<ParticipantId, ParticipantId> _participantByConnection = {};
  final Map<ParticipantId, EphemeralKeyPair> _pendingMasterKeyPairs = {};

  // Visitor side: this device's single connection to the master.
  ParticipantId? _masterConnection;
  Uint8List? _visitorSessionKey;
  int _visitorLastAcceptedFromMaster = -1;
  Completer<Result<Unit, Failure>>? _joinCompleter;

  RoomSessionController({
    required SessionTransport transport,
    required RoomDiscovery discovery,
    required HandshakeService handshakeService,
    required DeviceId selfDeviceId,
    EnvelopeAuthenticator? authenticator,
    DateTime Function()? now,
    Duration tickInterval = const Duration(seconds: 5),
    Random? random,
  })  : _transport = transport,
        _discovery = discovery,
        _handshakeService = handshakeService,
        _selfDeviceId = selfDeviceId,
        _authenticator = authenticator ?? EnvelopeAuthenticator(),
        _now = now ?? DateTime.now,
        _tickInterval = tickInterval,
        _random = random ?? Random.secure();

  Stream<RoomSessionSnapshot> get snapshots => _snapshotsController.stream;

  Future<Result<RoomId, Failure>> createRoom() async {
    await _transport.listen(0);
    final roomId = RoomId(_generateRoomId());
    final code = _generateCode();
    final room = Room(
      id: roomId,
      code: code,
      masterId: _selfDeviceId,
      state: RoomLifecycle.advertising,
    );
    _stateMachine = RoomSessionStateMachine(room: room);
    _emitSnapshot();
    await _discovery.advertise(roomId, _transport.boundPort);

    _transport.incomingConnections.listen(_handleIncomingConnection);
    _transport.closedConnections.listen(_handleConnectionClosed);
    _startTicking();

    return Result.success(roomId);
  }

  Stream<DiscoveredRoom> discoverRooms() {
    return _discovery.discover().map((room) {
      _knownRooms[room.id] = room;
      return room;
    });
  }

  Future<Result<Unit, Failure>> requestJoin(RoomId room, String code) async {
    final discovered = _knownRooms[room];
    if (discovered == null) {
      return Result.failure(NotFoundFailure(code: 'session.room-not-found'));
    }

    _joinCompleter = Completer<Result<Unit, Failure>>();
    final connection = await _transport.connect(
      discovered.host,
      discovered.port,
    );
    _masterConnection = connection;
    _transport.receive(connection).listen((chunk) {
      for (final frame in _reassemble(connection, chunk)) {
        unawaited(_handleVisitorMessage(SessionWireMessage.decode(frame)));
      }
    });

    await _sendMessage(
      connection,
      JoinRequestMessage(deviceId: _selfDeviceId.value, code: code),
    );

    return _joinCompleter!.future;
  }

  Future<Result<Unit, Failure>> approve(ParticipantId id) {
    final result = _stateMachine!.approve(id, _now());
    return result.when(
      success: _sendHandshakeInit,
      failure: (f) => Future.value(Result.failure(f)),
    );
  }

  Result<Unit, Failure> reject(ParticipantId id) {
    final result = _stateMachine!.reject(id);
    if (result.isSuccess) {
      _emitSnapshot();
    }
    return result;
  }

  Future<Result<Unit, Failure>> _sendHandshakeInit(ParticipantId id) async {
    final keyPair = await _handshakeService.generateEphemeralKeyPair();
    _pendingMasterKeyPairs[id] = keyPair;
    final connection = _connectionByParticipant[id];
    if (connection == null) {
      return Result.failure(
        NotFoundFailure(code: 'session.participant-not-found'),
      );
    }
    await _sendMessage(
      connection,
      HandshakeInitMessage(publicKey: keyPair.publicKeyBytes),
    );
    _emitSnapshot();
    return const Result.success(Unit());
  }

  void _handleIncomingConnection(ParticipantId connection) {
    _transport.receive(connection).listen((chunk) {
      for (final frame in _reassemble(connection, chunk)) {
        unawaited(
          _handleMasterMessage(connection, SessionWireMessage.decode(frame)),
        );
      }
    });
  }

  Future<void> _handleMasterMessage(
    ParticipantId connection,
    SessionWireMessage message,
  ) async {
    if (message is JoinRequestMessage) {
      final result = _stateMachine!.requestJoin(
        DeviceId(message.deviceId),
        message.code,
        _now(),
      );
      if (result.isFailure) {
        result.when(
          success: (_) {},
          failure: (f) async {
            await _sendMessage(
              connection,
              JoinRejectedMessage(reasonCode: f.code),
            );
            await _transport.close(connection);
          },
        );
        return;
      }
      final participantId = ParticipantId(message.deviceId);
      _connectionByParticipant[participantId] = connection;
      _participantByConnection[connection] = participantId;
      _emitSnapshot();
      return;
    }

    if (message is HandshakeResponseMessage) {
      final participantId = _participantByConnection[connection];
      final keyPair = participantId == null
          ? null
          : _pendingMasterKeyPairs.remove(participantId);
      if (participantId == null || keyPair == null) {
        return;
      }
      final derived = await _handshakeService.deriveSessionKey(
        keyPair,
        message.publicKey,
      );
      derived.when(
        success: (key) {
          _stateMachine!.completeHandshake(participantId, key);
          _emitSnapshot();
        },
        failure: (_) {},
      );
      return;
    }

    if (message is EnvelopeMessage) {
      final envelope = Envelope(
        senderId: message.senderId,
        sequence: message.sequence,
        payload: message.payload,
        hmac: message.hmac,
      );
      _stateMachine!.acceptEnvelope(
        envelope,
        _now(),
        requiresMasterRole: message.requiresMasterRole,
      );
      _emitSnapshot();
    }
  }

  Future<void> _handleVisitorMessage(SessionWireMessage message) async {
    if (message is JoinRejectedMessage) {
      _joinCompleter?.complete(
        Result.failure(ValidationFailure(code: message.reasonCode)),
      );
      return;
    }

    if (message is HandshakeInitMessage) {
      final keyPair = await _handshakeService.generateEphemeralKeyPair();
      final derived = await _handshakeService.deriveSessionKey(
        keyPair,
        message.publicKey,
      );
      await derived.when(
        success: (key) async {
          _visitorSessionKey = key;
          await _sendMessage(
            _masterConnection!,
            HandshakeResponseMessage(publicKey: keyPair.publicKeyBytes),
          );
          _joinCompleter?.complete(const Result.success(Unit()));
        },
        failure: (f) async {
          _joinCompleter?.complete(Result.failure(f));
        },
      );
      return;
    }

    if (message is EnvelopeMessage) {
      final sessionKey = _visitorSessionKey;
      if (sessionKey == null) {
        return;
      }
      final envelope = Envelope(
        senderId: message.senderId,
        sequence: message.sequence,
        payload: message.payload,
        hmac: message.hmac,
      );
      final result = _authenticator.verify(
        envelope,
        sessionKey,
        _visitorLastAcceptedFromMaster,
      );
      result.when(
        success: (_) => _visitorLastAcceptedFromMaster = message.sequence,
        failure: (_) {},
      );
    }
  }

  void _handleConnectionClosed(ParticipantId connection) {
    final participantId = _participantByConnection.remove(connection);
    if (participantId != null) {
      _connectionByParticipant.remove(participantId);
      _stateMachine?.disconnect(participantId);
      _emitSnapshot();
    }
  }

  List<Uint8List> _reassemble(ParticipantId connection, Uint8List chunk) {
    final reassembler = _reassemblers.putIfAbsent(
      connection,
      () => FrameReassembler(),
    );
    return reassembler.addChunk(chunk);
  }

  Future<void> _sendMessage(
    ParticipantId connection,
    SessionWireMessage message,
  ) {
    return _transport.send(connection, encodeFrame(message.encode()));
  }

  void _startTicking() {
    _tickTimer = Timer.periodic(_tickInterval, (_) {
      _stateMachine?.tick(_now());
      _emitSnapshot();
    });
  }

  void _emitSnapshot() {
    final machine = _stateMachine;
    if (machine == null) {
      return;
    }
    _snapshotsController.add(
      RoomSessionSnapshot(
          room: machine.room, participants: machine.allParticipants),
    );
  }

  String _generateRoomId() => List.generate(
        16,
        (_) => _random.nextInt(16).toRadixString(16),
      ).join();

  String _generateCode() => (1000 + _random.nextInt(9000)).toString();

  void dispose() {
    _tickTimer?.cancel();
    unawaited(_snapshotsController.close());
  }
}
