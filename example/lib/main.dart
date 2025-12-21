import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as classic;
import 'package:permission_handler/permission_handler.dart';

import 'package:dart_obd/obd.dart';
import 'package:dart_obd/connection/obd_connection.dart';
import 'package:dart_obd/utils/exceptions.dart';

void main() => runApp(const ObdTestApp());

class ObdTestApp extends StatelessWidget {
  const ObdTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: ObdHome());
  }
}

class ObdHome extends StatefulWidget {
  const ObdHome({super.key});

  @override
  State<ObdHome> createState() => _ObdHomeState();
}

class _ObdHomeState extends State<ObdHome> {
  final Map<String, classic.BluetoothDiscoveryResult> _results = {};
  StreamSubscription<classic.BluetoothDiscoveryResult>? _discoverySub;
  bool _scanning = false;
  bool _connecting = false;
  bool _loadingBonded = false;

  OBD? _obd;
  List<classic.BluetoothDevice> _bondedDevices = [];

  String _status = 'disconnected';
  String _result = '';

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    await _ensurePermissions();
    await classic.FlutterBluetoothSerial.instance.requestEnable();
    await _loadBondedDevices();
  }

  Future<void> _ensurePermissions() async {
    final toRequest = <Permission>[
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ];
    await toRequest.request();
  }

  Future<void> _loadBondedDevices() async {
    if (_loadingBonded) return;
    setState(() => _loadingBonded = true);
    try {
      final devices = await classic.FlutterBluetoothSerial.instance.getBondedDevices();
      if (!mounted) return;
      setState(() => _bondedDevices = devices);
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'bonded devices error: $e');
    } finally {
      if (!mounted) return;
      setState(() => _loadingBonded = false);
    }
  }

  Future<void> _startScan() async {
    if (_scanning) return;
    await _ensurePermissions();
    setState(() {
      _scanning = true;
      _results.clear();
      _status = 'scanning';
    });

    // Ensure Bluetooth is on
    await classic.FlutterBluetoothSerial.instance.requestEnable();

    _discoverySub = classic.FlutterBluetoothSerial.instance
        .startDiscovery()
        .listen((classic.BluetoothDiscoveryResult r) {
      final id = r.device.address;
      _results[id] = r;
      if (mounted) setState(() {});
    });

    try {
      await Future.delayed(const Duration(seconds: 10));
    } finally {
      await _stopScan();
      if (mounted && _status == 'scanning') {
        setState(() => _status = 'scan finished');
      }
    }
  }

  Future<void> _stopScan() async {
    _scanning = false;
    try {
      await classic.FlutterBluetoothSerial.instance.cancelDiscovery();
    } catch (_) {}
    await _discoverySub?.cancel();
    _discoverySub = null;
  }

  String _deviceName(classic.BluetoothDiscoveryResult r) {
    final name = r.device.name;
    if (name != null && name.isNotEmpty) return name;
    for (final d in _bondedDevices) {
      if (d.address == r.device.address) {
        final bondedName = d.name;
        if (bondedName != null && bondedName.isNotEmpty) return bondedName;
        break;
      }
    }
    return '(unknown)';
  }

  Future<void> _pairDevice(classic.BluetoothDevice device) async {
    await _ensurePermissions();
    setState(() => _status = 'pairing ${device.address}');
    final bonded = await classic.FlutterBluetoothSerial.instance
        .bondDeviceAtAddress(device.address);
    if (!mounted) return;
    if (bonded == true) {
      await _loadBondedDevices();
      setState(() => _status = 'paired ${device.address}');
    } else {
      setState(() => _status = 'pairing failed');
    }
  }

  Future<void> _connectTo(classic.BluetoothDevice device) async {
    if (_connecting) return;
    setState(() {
      _connecting = true;
      _status = 'connecting';
    });

    await _ensurePermissions();
    await _stopScan();

    try {
      var connectDevice = device;
      if (!device.isBonded) {
        final bonded = await classic.FlutterBluetoothSerial.instance
            .bondDeviceAtAddress(device.address);
        if (bonded != true) {
          if (!mounted) return;
          setState(() => _status = 'pairing failed');
          return;
        }
        await _loadBondedDevices();
        for (final d in _bondedDevices) {
          if (d.address == device.address) {
            connectDevice = d;
            break;
          }
        }
      }

      final conn = ClassicObdConnection(connectDevice);
      final obd = OBD(connection: conn);
      await obd.connect();
      if (!mounted) return;
      setState(() {
        _obd = obd;
        _status = 'connected to ${connectDevice.address}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'error: $e');
    } finally {
      if (!mounted) return;
      setState(() => _connecting = false);
    }
  }

  Future<void> _queryRpm() async {
    try {
      final obd = _obd;
      if (obd == null) {
        setState(() => _result = 'not connected');
        return;
      }
      final res = await obd.queryName('RPM');
      if (!mounted) return;
      setState(() => _result = res.toString());
    } catch (e) {
      if (!mounted) return;
      setState(() => _result = 'error: $e');
    }
  }

  @override
  void dispose() {
    _stopScan();
    _obd?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final devices = _results.values.toList()
      ..sort((a, b) => (b.rssi ?? -999).compareTo(a.rssi ?? -999));
    final bonded = _bondedDevices.toList()
      ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));

    return Scaffold(
      appBar: AppBar(title: const Text('dart_obd classic BT test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: $_status'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                ElevatedButton(
                  onPressed: _scanning ? null : _startScan,
                  child: Text(_scanning ? 'Scanning...' : 'Scan'),
                ),
                ElevatedButton(
                  onPressed: _loadingBonded ? null : _loadBondedDevices,
                  child: Text(_loadingBonded ? 'Loading bonded...' : 'Refresh bonded'),
                ),
                ElevatedButton(onPressed: _queryRpm, child: const Text('Query RPM')),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'This uses Classic Bluetooth. Make sure the ELM adapter is powered and paired/visible.',
            ),
            const SizedBox(height: 12),
            Text('Bonded devices (${bonded.length})'),
            const SizedBox(height: 8),
            Expanded(
              child: bonded.isEmpty
                  ? const Text('No bonded devices yet. Pair in system settings or tap Scan.')
                  : ListView.separated(
                      itemCount: bonded.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final d = bonded[index];
                        final name = d.name?.isNotEmpty == true ? d.name! : '(unknown)';
                        return ListTile(
                          title: Text(name),
                          subtitle: Text('${d.address} - bonded'),
                          trailing: TextButton(
                            onPressed: _connecting ? null : () => _connectTo(d),
                            child: const Text('Connect'),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            Text('Devices (${devices.length})'),
            const SizedBox(height: 8),
            Expanded(
              child: devices.isEmpty
                  ? const Text('No devices yet. Tap Scan and ensure Bluetooth is enabled.')
                  : ListView.separated(
                      itemCount: devices.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final r = devices[index];
                        final isBonded = r.device.isBonded;
                        return ListTile(
                          title: Text(_deviceName(r)),
                          subtitle: Text(
                            '${r.device.address} - RSSI ${r.rssi ?? 0} - ${isBonded ? "bonded" : "unbonded"}',
                          ),
                          trailing: TextButton(
                            onPressed: _connecting
                                ? null
                                : isBonded
                                    ? () => _connectTo(r.device)
                                    : () => _pairDevice(r.device),
                            child: Text(isBonded ? 'Connect' : 'Pair'),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            Text('Last result: $_result'),
          ],
        ),
      ),
    );
  }
}

class ClassicObdConnection implements OBDConnection {
  final classic.BluetoothDevice device;

  classic.BluetoothConnection? _conn;
  StreamSubscription<Uint8List>? _sub;
  final _lineCtrl = StreamController<String>.broadcast();
  bool _connected = false;

  ClassicObdConnection(this.device);

  @override
  bool get isConnected => _connected;

  @override
  Stream<String> get lines => _lineCtrl.stream;

  @override
  Future<void> connect() async {
    try {
      _conn = await classic.BluetoothConnection.toAddress(device.address);
      _connected = true;
      final buffer = StringBuffer();
      _sub = _conn!.input?.listen((data) {
        final chunk = utf8.decode(data, allowMalformed: true);
        buffer.write(chunk);
        var text = buffer.toString();
        while (true) {
          final idxR = text.indexOf('\r');
          final idxN = text.indexOf('\n');
          final idx = _minPositive(idxR, idxN);
          if (idx == -1) break;
          final line = text.substring(0, idx).trim();
          if (line.isNotEmpty) _lineCtrl.add(line);
          text = text.substring(idx + 1);
        }
        buffer
          ..clear()
          ..write(text);
      });
    } catch (e, st) {
      _connected = false;
      throw OBDConnectionException('Classic BT connect failed', cause: e, stackTrace: st);
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
    await _conn?.close();
    _conn = null;
  }

  @override
  Future<void> write(String data) async {
    final c = _conn;
    if (!_connected || c == null) throw OBDNotConnectedException();
    c.output.add(Uint8List.fromList(utf8.encode(data)));
    await c.output.allSent;
  }
}
