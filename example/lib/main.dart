import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:dart_obd/obd.dart';
import 'package:dart_obd/connection/bluetooth_connection.dart';

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
  static const String _serviceUuid = '0000fff0-0000-1000-8000-00805f9b34fb';
  static const String _txCharUuid = '0000fff1-0000-1000-8000-00805f9b34fb';
  static const String _rxCharUuid = '0000fff1-0000-1000-8000-00805f9b34fb';

  OBD? _obd;
  final Map<String, ScanResult> _scanResults = {};
  StreamSubscription<List<ScanResult>>? _scanSub;
  bool _scanning = false;
  bool _connecting = false;

  String _status = 'disconnected';
  String _result = '';

  String _deviceName(ScanResult r) {
    final adv = r.advertisementData.advName;
    if (adv.isNotEmpty) return adv;
    final platform = r.device.platformName;
    if (platform.isNotEmpty) return platform;
    return '(unknown)';
  }

  Future<void> _startScan() async {
    if (_scanning) return;
    setState(() {
      _scanning = true;
      _status = 'scanning';
      _scanResults.clear();
    });

    _scanSub ??= FlutterBluePlus.scanResults.listen((results) {
      var changed = false;
      for (final r in results) {
        final id = r.device.remoteId.str;
        _scanResults[id] = r;
        changed = true;
      }
      if (changed && mounted) setState(() {});
    });

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 8),
        androidUsesFineLocation: true,
      );
      await Future.delayed(const Duration(seconds: 8));
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'scan error: $e');
    } finally {
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _scanning = false;
        if (_status == 'scanning') _status = 'scan stopped';
      });
    }
  }

  Future<void> _connectTo(BluetoothDevice device) async {
    if (_connecting) return;
    setState(() {
      _connecting = true;
      _status = 'connecting';
    });
    try {
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}

      final conn = BluetoothConnection(
        device: device,
        serviceUuid: Guid(_serviceUuid),
        txCharUuid: Guid(_txCharUuid),
        rxCharUuid: Guid(_rxCharUuid),
      );

      final obd = OBD(connection: conn);
      await obd.connect();
      if (!mounted) return;
      setState(() {
        _obd = obd;
        _status = 'connected to ${device.remoteId.str}';
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
    final sub = _scanSub;
    if (sub != null) {
      unawaited(sub.cancel());
    }
    unawaited(FlutterBluePlus.stopScan());
    final obd = _obd;
    if (obd != null) {
      unawaited(obd.disconnect());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = _scanResults.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));

    return Scaffold(
      appBar: AppBar(title: const Text('dart_obd test')),
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
                ElevatedButton(onPressed: _queryRpm, child: const Text('Query RPM')),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Only BLE devices appear here. Many ELM327 adapters are Classic '
              'Bluetooth (SPP) and will not show up in BLE scans.',
            ),
            const SizedBox(height: 12),
            Text('Devices (${results.length})'),
            const SizedBox(height: 8),
            Expanded(
              child: results.isEmpty
                  ? const Text('No BLE devices found yet. Tap Scan.')
                  : ListView.separated(
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final r = results[index];
                        return ListTile(
                          title: Text(_deviceName(r)),
                          subtitle: Text('${r.device.remoteId.str} • RSSI ${r.rssi}'),
                          trailing: TextButton(
                            onPressed: _connecting ? null : () => _connectTo(r.device),
                            child: const Text('Connect'),
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
