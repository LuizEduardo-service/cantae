import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cantae/domain/session/ids.dart';
import 'package:cantae/domain/session/session_transport.dart';

class TcpSessionTransport implements SessionTransport {
  ServerSocket? _serverSocket;
  int _nextConnectionId = 0;

  final Map<ParticipantId, Socket> _sockets = {};
  final Map<ParticipantId, StreamController<Uint8List>> _receiveControllers =
      {};
  final _incomingController = StreamController<ParticipantId>.broadcast();
  final _closedController = StreamController<ParticipantId>.broadcast();

  @override
  int get boundPort => _serverSocket!.port;

  @override
  Stream<ParticipantId> get incomingConnections => _incomingController.stream;

  @override
  Stream<ParticipantId> get closedConnections => _closedController.stream;

  @override
  Future<void> listen(int port) async {
    _serverSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    _serverSocket!.listen((socket) {
      final id = _registerSocket(socket);
      _incomingController.add(id);
    });
  }

  @override
  Future<ParticipantId> connect(String host, int port) async {
    final socket = await Socket.connect(host, port);
    return _registerSocket(socket);
  }

  ParticipantId _registerSocket(Socket socket) {
    final id = ParticipantId('conn-${_nextConnectionId++}');
    _sockets[id] = socket;
    // A single-subscription controller buffers bytes that arrive before
    // receive(id) is listened to; a broadcast controller would silently drop
    // them, since nothing is listening yet at the moment they arrive.
    final controller = StreamController<Uint8List>();
    _receiveControllers[id] = controller;
    socket.listen(
      (data) => controller.add(Uint8List.fromList(data)),
      onDone: () => _handlePeerClosed(id),
      onError: (_) => _handlePeerClosed(id),
      cancelOnError: true,
    );
    return id;
  }

  void _handlePeerClosed(ParticipantId id) {
    if (_sockets.remove(id) != null) {
      _receiveControllers.remove(id)?.close();
      _closedController.add(id);
    }
  }

  @override
  Stream<Uint8List> receive(ParticipantId id) {
    return _receiveControllers[id]?.stream ?? const Stream.empty();
  }

  @override
  Future<void> send(ParticipantId id, Uint8List bytes) async {
    final socket = _sockets[id];
    if (socket == null) {
      return;
    }
    socket.add(bytes);
    await socket.flush();
  }

  @override
  Future<void> close(ParticipantId id) async {
    final socket = _sockets.remove(id);
    if (socket == null) {
      return;
    }
    // Not awaited: a single-subscription controller's close() future only
    // resolves once a listener has drained it, and receive(id) may never
    // have been listened to.
    unawaited(_receiveControllers.remove(id)?.close());
    await socket.close();
  }

  /// Abruptly kills the underlying socket (RST, no graceful FIN) instead of
  /// the orderly shutdown `close()` performs. Not part of the `SessionTransport`
  /// domain port — this is a transport-level capability for forcing off an
  /// unresponsive peer, distinct from the normal disconnect path.
  Future<void> destroy(ParticipantId id) async {
    final socket = _sockets.remove(id);
    if (socket == null) {
      return;
    }
    unawaited(_receiveControllers.remove(id)?.close());
    socket.destroy();
  }
}
