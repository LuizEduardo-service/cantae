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
  final Map<ParticipantId, StreamSubscription<Uint8List>> _socketSubscriptions =
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
    _socketSubscriptions[id] = socket.listen(
      (data) {
        // Bytes already in flight when this side closed are meaningless.
        if (!controller.isClosed) controller.add(Uint8List.fromList(data));
      },
      onDone: () => _handlePeerClosed(id),
      onError: (_) => _handlePeerClosed(id),
      cancelOnError: true,
    );
    return id;
  }

  void _handlePeerClosed(ParticipantId id) {
    if (_sockets.remove(id) != null) {
      _socketSubscriptions.remove(id);
      _receiveControllers.remove(id)?.close();
      _closedController.add(id);
    }
  }

  @override
  Stream<Uint8List> receive(ParticipantId id) {
    return _receiveControllers[id]?.stream ?? const Stream.empty();
  }

  /// The write in flight per socket. A socket refuses `add`/`close` while a
  /// `flush` is pending ("StreamSink is bound to a stream"), so writes are
  /// chained and [close] waits for the last one.
  final Map<ParticipantId, Future<void>> _pendingWrites = {};

  @override
  Future<void> send(ParticipantId id, Uint8List bytes) async {
    final socket = _sockets[id];
    if (socket == null) {
      return;
    }
    final previous = _pendingWrites[id];
    Future<void> writeNow() {
      if (!identical(_sockets[id], socket)) return Future<void>.value();
      socket.add(bytes);
      return socket.flush();
    }

    final write = previous == null
        ? writeNow()
        : previous.then((_) => writeNow(), onError: (Object _) => writeNow());
    _pendingWrites[id] = write;
    try {
      await write;
    } finally {
      if (identical(_pendingWrites[id], write)) _pendingWrites.remove(id);
    }
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
    unawaited(_socketSubscriptions.remove(id)?.cancel());
    unawaited(_receiveControllers.remove(id)?.close());
    final pending = _pendingWrites.remove(id);
    if (pending != null) {
      try {
        await pending;
      } on Object {
        // The peer is gone; closing is all that is left.
      }
    }
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
    unawaited(_socketSubscriptions.remove(id)?.cancel());
    unawaited(_receiveControllers.remove(id)?.close());
    socket.destroy();
  }
}
