import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:usb_serial/usb_serial.dart';

import '../utils/exceptions.dart';
import 'obd_connection.dart';

/// USB serial connection via usb_serial.
/// Works on Android; iOS support depends on hardware/accessories.
class SerialConnection implements OBDConnection {
  final UsbDevice device;
  final int baudRate;
  final int dataBits;
  final int stopBits;
  final int parity;

  UsbPort? _port;
  StreamSubscription<Uint8List>? _sub;
  final _lineCtrl = StreamController<String>.broadcast();

  bool _connected = false;

  SerialConnection({
    required this.device,
    this.baudRate = 38400,
    this.dataBits = UsbPort.DATABITS_8,
    this.stopBits = UsbPort.STOPBITS_1,
    this.parity = UsbPort.PARITY_NONE,
  });

  @override
  bool get isConnected => _connected;

  @override
  Stream<String> get lines => _lineCtrl.stream;

  @override
  Future<void> connect() async {
    try {
      final port = await device.create();
      if (port == null) throw OBDConnectionException('Could not open USB serial port');
      _port = port;

      final ok = await port.open();
      if (!ok) throw OBDConnectionException('Failed to open USB serial port');

      await port.setDTR(true);
      await port.setRTS(true);
      await port.setPortParameters(baudRate, dataBits, stopBits, parity);

      final buffer = StringBuffer();
      _sub = port.inputStream?.listen((data) {
        final chunk = utf8.decode(data, allowMalformed: true);
        buffer.write(chunk);
        var text = buffer.toString();
        // Split on CR/LF
        while (true) {
          final idxR = text.indexOf('\r');
          final idxN = text.indexOf('\n');
          final idx = _minPositive(idxR, idxN);
          if (idx == -1) break;
          final line = text.substring(0, idx).trim();
          if (line.isNotEmpty) _lineCtrl.add(line);
          text = text.substring(idx + 1);
        }
        buffer.clear();
        buffer.write(text);
      });

      _connected = true;
    } catch (e, st) {
      _connected = false;
      throw OBDConnectionException('Serial connect failed', cause: e, stackTrace: st);
    }
  }

  int _minPositive(int a, int b) {
    if (a == -1) return b;
    if (b == -1) return a;
    return a < b ? a : b;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    await _sub?.cancel();
    _sub = null;
    await _port?.close();
    _port = null;
  }

  @override
  Future<void> write(String data) async {
    final p = _port;
    if (!_connected || p == null) throw OBDNotConnectedException();
    await p.write(Uint8List.fromList(utf8.encode(data)));
  }
}
