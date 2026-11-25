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
    // Regression (flaky-tests): close() closed the receive controller but
    // kept listening to the socket, so bytes the peer sent afterwards were
    // added to a closed controller: "Bad state: Cannot add event after
    // closing", an uncaught error in whichever test was running.
    for (final abrupt in [false, true]) {
      test('bytes arriving after ${abrupt ? 'destroy' : 'close'}() are dropped',
          () async {
        final master = TcpSessionTransport();
        final visitor = TcpSessionTransport();
        await master.listen(0);
        final incoming = master.incomingConnections.first;
        final visitorConnId =
            await visitor.connect('127.0.0.1', master.boundPort);
        final masterConnId = await incoming;

        if (abrupt) {
          await master.destroy(masterConnId);
        } else {
          await master.close(masterConnId);
        }
        await visitor.send(visitorConnId, Uint8List.fromList([1, 2, 3]));
        // Long enough for the loopback bytes to reach the master.
        await Future<void>.delayed(const Duration(milliseconds: 300));

        await visitor.close(visitorConnId);
      });
    }
  });
}
