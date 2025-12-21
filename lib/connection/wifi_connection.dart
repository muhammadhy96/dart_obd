import 'dart:async';
import 'dart:convert';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../utils/exceptions.dart';
import 'obd_connection.dart';

/// WiFi connection using socket.io (per request).
/// Many WiFi ELM adapters actually expose a raw TCP socket (port 35000).
/// If your adapter is raw TCP, implement another connection using dart:io Socket.
class WifiConnection implements OBDConnection {
  final String url;
  final Map<String, dynamic>? options;

  final _lineCtrl = StreamController<String>.broadcast();
  io.Socket? _socket;
  bool _connected = false;

  WifiConnection({required this.url, this.options});

  @override
  bool get isConnected => _connected;

  @override
  Stream<String> get lines => _lineCtrl.stream;

  @override
  Future<void> connect() async {
    try {
      final sock = io.io(url, {
        'transports': ['websocket'],
        'autoConnect': false,
        ...?options,
      });
      _socket = sock;

      final completer = Completer<void>();
      sock.onConnect((_) {
        _connected = true;
        if (!completer.isCompleted) completer.complete();
      });
      sock.onDisconnect((_) {
        _connected = false;
      });
      sock.onError((err) {
        if (!completer.isCompleted) {
          completer.completeError(OBDConnectionException('WiFi socket error', cause: err));
        }
      });
      sock.on('data', (dynamic payload) {
        final s = payload is String ? payload : jsonEncode(payload);
        _emitText(s);
      });
      sock.on('message', (dynamic payload) {
        final s = payload is String ? payload : jsonEncode(payload);
        _emitText(s);
      });

      sock.connect();
      await completer.future.timeout(const Duration(seconds: 5));
    } catch (e, st) {
      _connected = false;
      throw OBDConnectionException('WiFi connect failed', cause: e, stackTrace: st);
    }
  }

  void _emitText(String chunk) {
    final normalized = chunk.replaceAll('\r', '\n');
    for (final line in normalized.split('\n')) {
      final t = line.trim();
      if (t.isNotEmpty) _lineCtrl.add(t);
    }
  }

  @override
  Future<void> disconnect() async {
    final s = _socket;
    _socket = null;
    _connected = false;
    s?.disconnect();
    s?.dispose();
  }

  @override
  Future<void> write(String data) async {
    final s = _socket;
    if (!_connected || s == null) throw OBDNotConnectedException();
    s.emit('data', data);
  }
}
