import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart'
    as classic;
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
  static const List<String> _livePids = <String>[
    'SPEED',
    'RPM',
    'INTAKE_TEMP',
    'MAF',
    'INTAKE_PRESSURE',
  ];

  final Map<String, classic.BluetoothDiscoveryResult> _results = {};
  StreamSubscription<classic.BluetoothDiscoveryResult>? _discoverySub;
  bool _scanning = false;
  bool _connecting = false;
  bool _loadingBonded = false;
  bool _livePolling = false;
  Future<void>? _pollingTask;
  int _pollCount = 0;
  Duration _lastPollDuration = Duration.zero;

  OBD? _obd;
  List<classic.BluetoothDevice> _bondedDevices = [];
  final Map<String, String> _liveValues = <String, String>{
    'SPEED': '--',
    'RPM': '--',
    'INTAKE_TEMP': '--',
    'MAF': '--',
    'INTAKE_PRESSURE': '--',
  };

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
      final devices = await classic.FlutterBluetoothSerial.instance
          .getBondedDevices();
      if (!mounted) return;
      setState(() => _bondedDevices = devices);
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'bonded devices error: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingBonded = false);
      }
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

    await _stopLivePolling();
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
      if (mounted) {
        setState(() => _connecting = false);
      }
    }
  }

  Future<void> _queryRpm() async {
    if (_livePolling) return;
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

  Future<void> _startLivePolling() async {
    if (_livePolling) return;
    final obd = _obd;
    if (obd == null) {
      setState(() => _status = 'not connected');
      return;
    }

    setState(() {
      _livePolling = true;
      _pollCount = 0;
      _lastPollDuration = Duration.zero;
      _status = 'live polling';
    });

    _pollingTask = _pollLoop(obd);
    unawaited(_pollingTask);
  }

  Future<void> _stopLivePolling() async {
    _livePolling = false;
    final task = _pollingTask;
    _pollingTask = null;
    if (task != null) {
      await task;
    }
    if (mounted) {
      setState(() {
        if (_status.startsWith('live polling')) {
          _status = 'live polling stopped';
        }
      });
    }
  }

  Future<void> _pollLoop(OBD obd) async {
    while (_livePolling) {
      final started = DateTime.now();
      String? firstError;

      for (final pid in _livePids) {
        if (!_livePolling) break;
        try {
          final res = await obd.queryName(pid);
          if (res.isNull) {
            _liveValues[pid] = 'null(${res.error ?? 'unknown'})';
          } else {
            _liveValues[pid] = '${res.value}';
          }
        } catch (e) {
          _liveValues[pid] = 'error(${e.runtimeType})';
          firstError ??= '$pid failed';
        }
      }

      final elapsed = DateTime.now().difference(started);
      if (!mounted) break;
      setState(() {
        _pollCount += 1;
        _lastPollDuration = elapsed;
        _result = _livePids
            .map((pid) => '$pid=${_liveValues[pid]}')
            .join(' | ');
        if (firstError == null) {
          _status = 'live polling';
        } else {
          _status = 'live polling (last error: $firstError)';
        }
      });

      // Keep polling continuously but yield to UI/frame scheduling.
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  @override
  void dispose() {
    _livePolling = false;
    _stopScan();
    _obd?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final devices = _results.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
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
                  child: Text(
                    _loadingBonded ? 'Loading bonded...' : 'Refresh bonded',
                  ),
                ),
                ElevatedButton(
                  onPressed: _livePolling ? null : _queryRpm,
                  child: const Text('Query RPM'),
                ),
                ElevatedButton(
                  onPressed: _livePolling ? null : _startLivePolling,
                  child: const Text('Start Live'),
                ),
                ElevatedButton(
                  onPressed: _livePolling ? _stopLivePolling : null,
                  child: const Text('Stop Live'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Live cycle: $_pollCount | Last cycle: ${_lastPollDuration.inMilliseconds} ms',
            ),
            const SizedBox(height: 8),
            Text(
              'SPEED: ${_liveValues['SPEED']}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              'RPM: ${_liveValues['RPM']}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              'IAT: ${_liveValues['INTAKE_TEMP']}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              'MAF: ${_liveValues['MAF']}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              'MAP: ${_liveValues['INTAKE_PRESSURE']}',
              style: const TextStyle(fontWeight: FontWeight.w600),
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
                  ? const Text(
                      'No bonded devices yet. Pair in system settings or tap Scan.',
                    )
                  : ListView.separated(
                      itemCount: bonded.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final d = bonded[index];
                        final name = d.name?.isNotEmpty == true
                            ? d.name!
                            : '(unknown)';
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
                  ? const Text(
                      'No devices yet. Tap Scan and ensure Bluetooth is enabled.',
                    )
                  : ListView.separated(
                      itemCount: devices.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final r = devices[index];
                        final isBonded = r.device.isBonded;
                        return ListTile(
                          title: Text(_deviceName(r)),
                          subtitle: Text(
                            '${r.device.address} - RSSI ${r.rssi} - ${isBonded ? "bonded" : "unbonded"}',
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
    Object? lastError;
    StackTrace? lastStackTrace;
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        await _connectOnce();
        return;
      } catch (e, st) {
        lastError = e;
        lastStackTrace = st;
        await disconnect();
        if (attempt == 1) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
    }

    throw OBDConnectionException(
      'Classic BT connect failed (${device.address})',
      cause: lastError,
      stackTrace: lastStackTrace,
    );
  }

  Future<void> _connectOnce() async {
    _conn = await classic.BluetoothConnection.toAddress(device.address);
    _connected = true;
    final buffer = StringBuffer();
    _sub = _conn!.input?.listen(
      (data) {
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
        if (text.contains('>')) {
          final parts = text.split('>');
          for (var i = 0; i < parts.length - 1; i++) {
            final line = parts[i].trim();
            if (line.isNotEmpty) _lineCtrl.add(line);
            _lineCtrl.add('>');
          }
          text = parts.last;
        }
        buffer
          ..clear()
          ..write(text);
      },
      onError: (_) {
        _connected = false;
      },
      onDone: () {
        _connected = false;
      },
    );
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
