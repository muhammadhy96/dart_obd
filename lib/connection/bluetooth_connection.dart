import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../utils/exceptions.dart';
import 'obd_connection.dart';

/// Bluetooth LE connection for adapters that expose a UART-like GATT service.
/// NOTE: Many cheap ELM327 "Bluetooth" adapters are Classic SPP, not BLE.
/// For those, use a Classic-BT plugin instead of flutter_blue_plus.
class BluetoothConnection implements OBDConnection {
  final BluetoothDevice device;
  final Guid serviceUuid;
  final Guid txCharUuid;
  final Guid rxCharUuid;

  BluetoothCharacteristic? _tx;
  BluetoothCharacteristic? _rx;

  final _lineCtrl = StreamController<String>.broadcast();
  StreamSubscription<List<int>>? _rxSub;

  final String prompt;

  BluetoothConnection({
    required this.device,
    required this.serviceUuid,
    required this.txCharUuid,
    required this.rxCharUuid,
    this.prompt = '>',
  });

  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Stream<String> get lines => _lineCtrl.stream;

  @override
  Future<void> connect() async {
    try {
      await device.connect(autoConnect: false);
      final services = await device.discoverServices();
      final svc = services.firstWhere((s) => s.uuid == serviceUuid);
      _tx = svc.characteristics.firstWhere((c) => c.uuid == txCharUuid);
      _rx = svc.characteristics.firstWhere((c) => c.uuid == rxCharUuid);

      await _rx!.setNotifyValue(true);

      final buffer = StringBuffer();
      _rxSub = _rx!.onValueReceived.listen((data) {
        final chunk = utf8.decode(data, allowMalformed: true);
        buffer.write(chunk);
        var text = buffer.toString();
        // Split on \r or \n or prompt
        while (true) {
          final idxR = text.indexOf('\r');
          final idxN = text.indexOf('\n');
          final idx = _minPositive(idxR, idxN);
          if (idx == -1) break;
          final line = text.substring(0, idx).trim();
          if (line.isNotEmpty) _lineCtrl.add(line);
          text = text.substring(idx + 1);
        }
        // If prompt appears without newline, emit it as its own line
        if (text.contains(prompt)) {
          final parts = text.split(prompt);
          for (var i = 0; i < parts.length - 1; i++) {
            final line = parts[i].trim();
            if (line.isNotEmpty) _lineCtrl.add(line);
            _lineCtrl.add(prompt);
          }
          text = parts.last;
        }
        buffer.clear();
        buffer.write(text);
      });

      _connected = true;
    } catch (e, st) {
      _connected = false;
      throw OBDConnectionException('Bluetooth connect failed', cause: e, stackTrace: st);
    }
  }

  int _minPositive(int a, int b) {
    if (a == -1) return b;
    if (b == -1) return a;
    return a < b ? a : b;
  }

  @override
  Future<void> disconnect() async {
    try {
      await _rxSub?.cancel();
      _rxSub = null;
      await device.disconnect();
    } finally {
      _connected = false;
    }
  }

  @override
  Future<void> write(String data) async {
    final tx = _tx;
    if (!_connected || tx == null) throw OBDNotConnectedException();
    final bytes = utf8.encode(data);
    await tx.write(bytes, withoutResponse: true);
  }
}
