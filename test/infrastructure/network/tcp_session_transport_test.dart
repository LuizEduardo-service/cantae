import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/infrastructure/network/tcp_session_transport.dart';

void main() {
  group('TcpSessionTransport', () {
    test('connect/send/receive round-trip over real loopback TCP', () async {
      final master = TcpSessionTransport();
      final visitor = TcpSessionTransport();
      await master.listen(0);

      final incoming = master.incomingConnections.first;
      final visitorConnId = await visitor.connect(
        '127.0.0.1',
        master.boundPort,
      );
      final masterConnId = await incoming;

      await visitor.send(
        visitorConnId,
        Uint8List.fromList('hello-master'.codeUnits),
      );
      final masterReceived = await master.receive(masterConnId).first;
      expect(
        String.fromCharCodes(masterReceived),
        equals('hello-master'),
      );

      await master.send(
        masterConnId,
        Uint8List.fromList('hello-visitor'.codeUnits),
      );
      final visitorReceived = await visitor.receive(visitorConnId).first;
      expect(
        String.fromCharCodes(visitorReceived),
        equals('hello-visitor'),
      );

      await master.close(masterConnId);
      await visitor.close(visitorConnId);
    });

    test(
        'a clean close() on one side is detected as closedConnections on the peer side',
        () async {
      final master = TcpSessionTransport();
      final visitor = TcpSessionTransport();
      await master.listen(0);

      final incoming = master.incomingConnections.first;
      final visitorConnId = await visitor.connect(
        '127.0.0.1',
        master.boundPort,
      );
      final masterConnId = await incoming;

      final masterClosedFuture = master.closedConnections.first;
      await visitor.close(visitorConnId);

      final closedId = await masterClosedFuture.timeout(
        const Duration(seconds: 5),
      );
      expect(closedId, equals(masterConnId));
    });

    test(
        'an abrupt socket kill (destroy) on one side is detected as closedConnections on the peer side',
        () async {
      final master = TcpSessionTransport();
      final visitor = TcpSessionTransport();
      await master.listen(0);

      final incoming = master.incomingConnections.first;
      final visitorConnId = await visitor.connect(
        '127.0.0.1',
        master.boundPort,
      );
      final masterConnId = await incoming;

      final masterClosedFuture = master.closedConnections.first;
      await visitor.destroy(visitorConnId);

      final closedId = await masterClosedFuture.timeout(
        const Duration(seconds: 5),
      );
      expect(closedId, equals(masterConnId));
    });
  });
}
