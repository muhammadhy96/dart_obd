# dart_obd (python-OBD parity port)

Pure Dart data-layer OBD-II library modeled after **python-OBD** (ELM327 adapters).

## Features

- ELM327 init + AT helpers (reset, echo/headers/spacing/timeout/protocol)
- Connections:
  - Bluetooth LE: `flutter_blue_plus`
  - WiFi (ELM over TCP-like socket.io bridges): `socket_io_client`
  - USB Serial: `usb_serial`
- Command database generated from python-OBD command tables
- Decoders ported from python-OBD, including **Mode 06 monitor decoding** using:
  - `UnitsAndScaling.py` UAS tables (full ID coverage)
  - `codes.py` `TEST_IDS` mapping (names + descriptions)

## Install

Add to your `pubspec.yaml`:

```yaml
dependencies:
  dart_obd:
    path: ../dart_obd
```

(or publish privately / git dependency)

## Quick start

### 1) Create a connection

#### Bluetooth LE

```dart
import 'package:dart_obd/obd.dart';
import 'package:dart_obd/connection/bluetooth_connection.dart';

final conn = BluetoothConnection(
  deviceId: 'AA:BB:CC:DD:EE:FF', // adapter MAC / ID
  serviceUuid: '0000fff0-0000-1000-8000-00805f9b34fb', // depends on adapter
  characteristicUuid: '0000fff1-0000-1000-8000-00805f9b34fb',
);
final obd = OBD(connection: conn);
await obd.connect();
```

#### USB Serial

```dart
import 'package:dart_obd/obd.dart';
import 'package:dart_obd/connection/serial_connection.dart';

final conn = SerialConnection(baudRate: 38400);
final obd = OBD(connection: conn);
await obd.connect();
```

#### WiFi

```dart
import 'package:dart_obd/obd.dart';
import 'package:dart_obd/connection/wifi_connection.dart';

final conn = WifiConnection(url: 'http://192.168.0.10:35000');
final obd = OBD(connection: conn);
await obd.connect();
```

### 2) Query a built-in command

```dart
final rpm = await obd.queryName('RPM');
print(rpm.value); // Quantity(...)
```

Or:

```dart
final cmd = obd.commandByName('SPEED');
final res = await obd.asyncQuery(cmd);
```

### 3) Supported PID scan (Mode 01)

```dart
final pids = await obd.getSupportedPIDs();
print(pids); // e.g. {'0C','0D','05', ...}
```

## Mode 06 monitors

python-OBD exposes many Mode 06 "monitor" commands (MIDs). In this port, those commands decode into a `MonitorObject`
that contains a list of `MonitorTest` results:

```dart
final res = await obd.queryName('MONITOR_CATALYST_B1');
final mon = res.value; // MonitorObject
for (final t in mon.tests) {
  print('${t.name}: ${t.desc} => ${t.value} (min=${t.min}, max=${t.max})');
}
```

- The test name/description comes from python-OBD `TEST_IDS`
- The `value/min/max` units and scaling come from python-OBD `UnitsAndScaling.UAS_IDS`

## Notes / parity

- This package is derived from python-OBD tables and logic. python-OBD is GPL-licensed; keep your distribution GPL-compatible.

