import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/data/session/room_session_controller.dart';
import 'package:cantae/data/session/session_wire_message.dart';
import 'package:cantae/domain/session/envelope_authenticator.dart';
import 'package:cantae/domain/session/handshake_service.dart';
import 'package:cantae/domain/session/ids.dart';
import 'package:cantae/domain/session/participant_session.dart';
import 'package:cantae/domain/session/room_discovery.dart';
import 'package:cantae/domain/session/room_session_snapshot.dart';
import 'package:cantae/infrastructure/network/tcp_session_transport.dart';

/// A fake mDNS discovery: new subscribers immediately see every currently
/// advertised room (like a real scan would), then continue receiving live
/// updates — a plain pass-through broadcast stream would drop advertise()
/// events that happened before a given visitor started discovering.
class _FakeRoomDiscovery implements RoomDiscovery {
  final StreamController<DiscoveredRoom> _bus;
  final Map<RoomId, DiscoveredRoom> _advertised;

  _FakeRoomDiscovery(this._bus, this._advertised);

  @override
  Future<void> advertise(RoomId id, int port) async {
    final room = DiscoveredRoom(id: id, host: '127.0.0.1', port: port);
    _advertised[id] = room;
    _bus.add(room);
  }

  @override
  Stream<DiscoveredRoom> discover() async* {
    for (final room in _advertised.values) {
      yield room;
    }
    yield* _bus.stream;
  }

  @override
  Future<void> stopAdvertising() async {}
}

RoomSessionController _newVisitor(
  StreamController<DiscoveredRoom> bus,
  Map<RoomId, DiscoveredRoom> advertised,
  String deviceId,
) {
  return RoomSessionController(
    transport: TcpSessionTransport(),
    discovery: _FakeRoomDiscovery(bus, advertised),
    handshakeService: HandshakeService(),
    selfDeviceId: DeviceId(deviceId),
  );
}

Future<DiscoveredRoom> _discover(RoomSessionController visitor, RoomId roomId) {
  return visitor.discoverRooms().firstWhere((r) => r.id == roomId);
}

ParticipantSession? _byId(RoomSessionSnapshot snapshot, String deviceId) {
  for (final p in snapshot.participants) {
    if (p.id == ParticipantId(deviceId)) {
      return p;
    }
  }
  return null;
}

void main() {
  test(
    'full session lifecycle: discover, join, approve, handshake, authenticated '
    'envelopes, adversarial rejection, and capacity',
    () async {
      final log = <String>[];
      void record(String line) {
        log.add(line);
        // ignore: avoid_print
        print(line);
      }

      final bus = StreamController<DiscoveredRoom>.broadcast();
      final advertised = <RoomId, DiscoveredRoom>{};
      final master = RoomSessionController(
        transport: TcpSessionTransport(),
        discovery: _FakeRoomDiscovery(bus, advertised),
        handshakeService: HandshakeService(),
        selfDeviceId: const DeviceId('master-device'),
      );
      addTearDown(master.dispose);
      addTearDown(bus.close);

      RoomSessionSnapshot? latest;
      master.snapshots.listen((s) => latest = s);

      Future<void> pollUntil(
        bool Function() condition, {
        Duration timeout = const Duration(seconds: 10),
      }) async {
        final deadline = DateTime.now().add(timeout);
        while (!condition()) {
          if (DateTime.now().isAfter(deadline)) {
            fail('condition not met within $timeout');
          }
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }

      // --- P1: discover, create room ---------------------------------
      final createResult = await master.createRoom();
      expect(createResult.isSuccess, isTrue);
      await pollUntil(() => latest != null);
      final roomId = latest!.room.id;
      final code = latest!.room.code;
      record('room created: $roomId (code $code)');

      // --- Fill 7 of 8 slots with filler participants (join+approve only) ---
      for (var i = 0; i < 7; i++) {
        final fillerId = 'filler-$i';
        final filler = _newVisitor(bus, advertised, fillerId);
        addTearDown(filler.dispose);
        final discovered = await _discover(filler, roomId);
        unawaited(filler.requestJoin(discovered.id, code));
        await pollUntil(
          () => latest!.participants.any(
            (p) =>
                p.id == ParticipantId(fillerId) &&
                p.state == ParticipantState.pendingApproval,
          ),
        );
        final approveResult = await master.approve(ParticipantId(fillerId));
        expect(approveResult.isSuccess, isTrue);
        record('filler $fillerId approved (slot ${i + 1}/8)');
      }

      // --- P1: main visitor completes the full join -> approve -> handshake flow ---
      final visitor = _newVisitor(bus, advertised, 'visitor-main');
      addTearDown(visitor.dispose);
      final discovered = await _discover(visitor, roomId);
      final joinResultFuture = visitor.requestJoin(discovered.id, code);

      await pollUntil(
        () =>
            _byId(latest!, 'visitor-main')?.state ==
            ParticipantState.pendingApproval,
      );
      final approveResult = await master.approve(
        const ParticipantId('visitor-main'),
      );
      expect(approveResult.isSuccess, isTrue);
      record('visitor-main approved (slot 8/8)');

      final joinResult = await joinResultFuture.timeout(
        const Duration(seconds: 5),
      );
      expect(joinResult.isSuccess, isTrue);
      await pollUntil(
        () =>
            _byId(latest!, 'visitor-main')?.state == ParticipantState.connected,
      );

      final masterSideKey = _byId(latest!, 'visitor-main')!.sessionKey!;
      final visitorSideKey = visitor.debugSessionKey!;
      expect(masterSideKey.length, equals(32));
      expect(visitorSideKey.length, equals(32));
      expect(masterSideKey, equals(visitorSideKey));
      record(
          'visitor-main handshake complete: matching 32-byte session keys on both ends');

      // --- P2: happy-path authenticated envelope is accepted -----------
      final send1 = await visitor.sendEnvelope(
        Uint8List.fromList(utf8.encode('hello-master')),
      );
      expect(send1.isSuccess, isTrue);
      await pollUntil(
        () => _byId(latest!, 'visitor-main')?.lastAcceptedSequence == 0,
      );
      record('happy-path envelope (seq 0) accepted');

      // --- P2 adversarial 1: tampered payload + stale HMAC is rejected ---
      // The "stale" HMAC is the real one computed for the sequence-0 envelope
      // that was already accepted; pairing it with a different payload at the
      // next sequence number makes it stale-but-correct-looking, not just garbage.
      final beforeTamper = _byId(latest!, 'visitor-main')!.lastAcceptedSequence;
      final staleHmac = EnvelopeAuthenticator()
          .sign(
            const ParticipantId('visitor-main'),
            0,
            Uint8List.fromList(utf8.encode('hello-master')),
            visitor.debugSessionKey!,
          )
          .hmac;
      await visitor.debugSendRaw(
        EnvelopeMessage(
          requiresMasterRole: false,
          senderId: const ParticipantId('visitor-main'),
          sequence: 1,
          hmac: staleHmac,
          payload: Uint8List.fromList(utf8.encode('tampered')),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 300));
      expect(
        _byId(latest!, 'visitor-main')!.lastAcceptedSequence,
        equals(beforeTamper),
      );
      record(
          'adversarial: tampered payload + stale HMAC rejected, state unchanged');

      // --- P2 adversarial 2: replayed sequence is rejected --------------
      final send2 = await visitor.sendEnvelope(
        Uint8List.fromList(utf8.encode('second-message')),
      );
      expect(send2.isSuccess, isTrue);
      await pollUntil(
        () => _byId(latest!, 'visitor-main')?.lastAcceptedSequence == 1,
      );
      final beforeReplay = _byId(latest!, 'visitor-main')!.lastAcceptedSequence;
      // Re-send the exact same already-accepted envelope: a VALID HMAC (signed
      // with the real session key) but a sequence number already accepted —
      // this must be rejected by the replay check, not the HMAC check.
      final validReplayEnvelope = EnvelopeAuthenticator().sign(
        const ParticipantId('visitor-main'),
        1,
        Uint8List.fromList(utf8.encode('second-message')),
        visitor.debugSessionKey!,
      );
      await visitor.debugSendRaw(
        EnvelopeMessage(
          requiresMasterRole: false,
          senderId: validReplayEnvelope.senderId,
          sequence: validReplayEnvelope.sequence,
          hmac: validReplayEnvelope.hmac,
          payload: validReplayEnvelope.payload,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 300));
      expect(
        _byId(latest!, 'visitor-main')!.lastAcceptedSequence,
        equals(beforeReplay),
      );
      record('adversarial: replayed sequence rejected, state unchanged');

      // --- P2 adversarial 3: Visitor sends a Master-only message type ---
      final beforeRoleViolation =
          _byId(latest!, 'visitor-main')!.lastAcceptedSequence;
      final roleResult = await visitor.sendEnvelope(
        Uint8List.fromList(utf8.encode('master-only-command')),
        requiresMasterRole: true,
      );
      expect(roleResult.isSuccess,
          isTrue); // the SEND succeeds; the master REJECTS it
      await Future.delayed(const Duration(milliseconds: 300));
      expect(
        _byId(latest!, 'visitor-main')!.lastAcceptedSequence,
        equals(beforeRoleViolation),
      );
      record(
          'adversarial: Visitor-sent Master-only message rejected, state unchanged');

      // --- A well-formed next-sequence message is still accepted afterward ---
      // (the rejected role-violation attempt above still consumed one sequence
      // number from the visitor's own counter even though master never applied
      // it, so the next accepted sequence is a gap forward, not beforeRoleViolation + 1
      // — that gap is explicitly legal per the spec's sequence-gap edge case.)
      final send3 = await visitor.sendEnvelope(
        Uint8List.fromList(utf8.encode('third-message')),
      );
      expect(send3.isSuccess, isTrue);
      await pollUntil(
        () =>
            (_byId(latest!, 'visitor-main')?.lastAcceptedSequence ?? -1) >
            beforeRoleViolation,
      );
      record(
          'well-formed next-sequence message accepted after adversarial attempts');

      // --- P1 capacity: a 9th join request is rejected once 8 are approved ---
      final ninth = _newVisitor(bus, advertised, 'ninth-visitor');
      addTearDown(ninth.dispose);
      final discoveredForNinth = await _discover(ninth, roomId);
      final ninthResult = await ninth
          .requestJoin(discoveredForNinth.id, code)
          .timeout(const Duration(seconds: 5));
      expect(ninthResult.isFailure, isTrue);
      ninthResult.when(
        success: (_) => fail('expected failure'),
        failure: (f) => expect(f.code, equals('session.room-full')),
      );
      record('9th join request rejected: session.room-full');

      // ignore: avoid_print
      print('--- full transition log (${log.length} steps) ---');
      for (final line in List<String>.from(log)) {
        // ignore: avoid_print
        print(line);
      }
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
