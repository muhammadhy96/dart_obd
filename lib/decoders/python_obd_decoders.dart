import 'dart:typed_data';
import '../utils/bit_array.dart';
import 'unit.dart';
import 'mode06_tables.dart';

typedef DecodeFn = dynamic Function(List<Uint8List> messages);

int bytesToInt(Uint8List b) {
  var v = 0;
  for (final x in b) v = (v << 8) | x;
  return v;
}

String bytesToHex(Uint8List b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join('').toUpperCase();

int twosComp(int val, int bits) {
  final sign = 1 << (bits - 1);
  if ((val & sign) != 0) {
    return val - (1 << bits);
  }
  return val;
}

// --------------------- basic numeric decoders (python-OBD parity) ---------------------
Quantity percent(List<Uint8List> m) {
  final d = m[0].sublist(2);
  final v = d[0] * 100.0 / 255.0;
  return Quantity(v, Unit.percent);
}

Quantity percentCentered(List<Uint8List> m) {
  final d = m[0].sublist(2);
  final v = (d[0] - 128) * 100.0 / 128.0;
  return Quantity(v, Unit.percent);
}

Quantity temp(List<Uint8List> m) {
  final d = m[0].sublist(2);
  final v = bytesToInt(Uint8List.fromList(d)) - 40.0;
  return Quantity(v, Unit.celsius);
}

Quantity pressure(List<Uint8List> m) {
  final d = m[0].sublist(2);
  return Quantity(d[0].toDouble() * 1000.0, Unit.pascal); // store Pa
}

Quantity rpm(List<Uint8List> m) {
  final d = m[0].sublist(2);
  final v = bytesToInt(Uint8List.fromList(d.sublist(0, 2))) / 4.0;
  return Quantity(v, Unit.rpm);
}

Quantity speed(List<Uint8List> m) {
  final d = m[0].sublist(2);
  return Quantity(d[0].toDouble(), Unit.kph);
}

Quantity timingAdvance(List<Uint8List> m) {
  final d = m[0].sublist(2);
  final v = (d[0] / 2.0) - 64.0;
  return Quantity(v, Unit.degree);
}

Quantity fuelPressure(List<Uint8List> m) {
  final d = m[0].sublist(2);
  return Quantity(d[0] * 3.0 * 1000.0, Unit.pascal);
}

Quantity maf(List<Uint8List> m) {
  final d = m[0].sublist(2);
  final v = bytesToInt(Uint8List.fromList(d.sublist(0, 2))) / 100.0;
  return Quantity(v, Unit.gps);
}

Quantity fuelRate(List<Uint8List> m) {
  final d = m[0].sublist(2);
  final v = bytesToInt(Uint8List.fromList(d.sublist(0, 2))) * 0.05;
  return Quantity(v, Unit.liters_per_hour);
}

Quantity absEvapPressure(List<Uint8List> m) {
  final d = m[0].sublist(2);
  final v = bytesToInt(Uint8List.fromList(d.sublist(0, 2))) / 200.0;
  return Quantity(v * 1000.0, Unit.pascal);
}

Quantity evapPressure(List<Uint8List> m) {
  final d = m[0].sublist(2);
  final a = twosComp(d[0], 8);
  final b = twosComp(d[1], 8);
  final v = ((a * 256.0) + b) / 4.0;
  return Quantity(v, Unit.pascal);
}

Quantity evapPressureAlt(List<Uint8List> m) {
  final d = m[0].sublist(2);
  final v = bytesToInt(Uint8List.fromList(d.sublist(0, 2))) - 32767.0;
  return Quantity(v, Unit.pascal);
}

Quantity absoluteLoad(List<Uint8List> m) {
  final d = m[0].sublist(2);
  final v = bytesToInt(Uint8List.fromList(d.sublist(0, 2))) * 100.0 / 255.0;
  return Quantity(v, Unit.percent);
}

Quantity sensorVoltage(List<Uint8List> m) {
  final d = m[0].sublist(2);
  final v = d[0] / 200.0;
  return Quantity(v, Unit.volt);
}

Quantity injectTiming(List<Uint8List> m) {
  final d = m[0].sublist(2);
  final v = (bytesToInt(Uint8List.fromList(d.sublist(0, 2))) - 26880.0) / 128.0;
  return Quantity(v, Unit.degree);
}

Quantity maxMaf(List<Uint8List> m) {
  final d = m[0].sublist(2);
  final v = d[0] * 10.0;
  return Quantity(v, Unit.gps);
}

Quantity currentCentered(List<Uint8List> m) {
  final d = m[0].sublist(2);
  if (d.length < 4) return Quantity(double.nan, Unit.milliampere);
  final v = (bytesToInt(Uint8List.fromList(d.sublist(2, 4))) / 256.0) - 128.0;
  return Quantity(v, Unit.milliampere);
}

// --------------------- bitfield decoders ---------------------

final Map<int, String> _airStatus = {
  0: "Upstream",
  1: "Downstream of catalytic converter",
  2: "From outside atmosphere or off",
  3: "Pump commanded on for diagnostics",
};

dynamic airStatus(List<Uint8List> m) {
  final d = m[0].sublist(2);
  final bits = BitArray(Uint8List.fromList(d));
  // python-OBD expects exactly 1 bit set in first byte
  final firstByte = bits.slice(0, 8);
  final set = firstByte.indexesWhereSet();
  if (set.length != 1) return null;
  final pos = set.first;
  // reverse indexing used by python-OBD
  final key = 7 - pos;
  return _airStatus[key];
}

bool auxInputStatus(List<Uint8List> m) {
  final d = m[0].sublist(2);
  return ((d[0] >> 7) & 1) == 1;
}

// --------------------- string/multipart decoders ---------------------

Uint8List? decodeEncodedString(List<Uint8List> messages, int length) {
  // python-OBD: payload after mode+pid, across multi frames
  final out = <int>[];
  for (final msg in messages) {
    final d = msg.sublist(2);
    out.addAll(d);
  }
  if (out.isEmpty) return null;
  if (out.length < length) return null;
  return Uint8List.fromList(out.sublist(0, length));
}

String rawString(List<Uint8List> messages) {
  // used for AT and VIN-like payloads sometimes, keep printable only
  final all = <int>[];
  for (final m in messages) all.addAll(m);
  return String.fromCharCodes(all.where((x) => x >= 0x20 && x <= 0x7E)).trim();
}

String? cvn(List<Uint8List> messages) {
  final b = decodeEncodedString(messages, 4);
  if (b == null) return null;
  return bytesToHex(b);
}

String? encodedString16(List<Uint8List> messages) {
  final b = decodeEncodedString(messages, 16);
  if (b == null) return null;
  return String.fromCharCodes(b.where((x) => x >= 0x20 && x <= 0x7E)).trim();
}

String? encodedString17(List<Uint8List> messages) {
  final b = decodeEncodedString(messages, 17);
  if (b == null) return null;
  return String.fromCharCodes(b.where((x) => x >= 0x20 && x <= 0x7E)).trim();
}

// --------------------- DTCs ---------------------

String? parseDtc(int a, int b) {
  if (a == 0 && b == 0) return null;
  final first = (a & 0xC0) >> 6;
  final letter = switch (first) { 0 => 'P', 1 => 'C', 2 => 'B', _ => 'U' };
  final d1 = (a & 0x30) >> 4;
  final d2 = (a & 0x0F);
  final d3 = (b & 0xF0) >> 4;
  final d4 = (b & 0x0F);
  String hx(int n) => n.toRadixString(16).toUpperCase();
  return '$letter$d1${hx(d2)}${hx(d3)}${hx(d4)}';
}

List<String> dtc(List<Uint8List> messages) {
  final d = <int>[];
  for (final m in messages) {
    final payload = m.sublist(2); // remove mode and count
    d.addAll(payload);
  }
  final out = <String>[];
  for (var i = 0; i + 1 < d.length; i += 2) {
    final code = parseDtc(d[i], d[i + 1]);
    if (code != null) out.add(code);
  }
  return out;
}

String? singleDtc(List<Uint8List> m) {
  final d = m[0].sublist(2);
  if (d.length < 2) return null;
  return parseDtc(d[0], d[1]);
}

// --------------------- fuel status ---------------------

final Map<int, String> _fuelStatus = {
  0: "Open loop due to insufficient engine temperature",
  1: "Closed loop, using oxygen sensor feedback to determine fuel mix",
  2: "Open loop due to engine load OR fuel cut due to deceleration",
  3: "Open loop due to system failure",
  4: "Closed loop, using at least one oxygen sensor but there is a fault in the feedback system",
};

List<String?> fuelStatus(List<Uint8List> m) {
  final d = m[0].sublist(2);
  if (d.length < 2) return [null, null];
  int decodeByte(int x) {
    // python uses bitarray with exactly one bit set
    final bits = BitArray(Uint8List.fromList([x]));
    final set = bits.indexesWhereSet();
    if (set.length != 1) return -1;
    return 7 - set.first;
  }
  final s1 = decodeByte(d[0]);
  final s2 = decodeByte(d[1]);
  return [ _fuelStatus[s1], _fuelStatus[s2] ];
}

// --------------------- OBD compliance / fuel type / oxygen sensors ---------------------

dynamic obdCompliance(List<Uint8List> m) => m[0].length > 2 ? m[0][2] : null;
dynamic fuelType(List<Uint8List> m) => m[0].length > 2 ? m[0][2] : null;

dynamic o2Sensors(List<Uint8List> m) => m[0].length > 2 ? m[0][2] : null;
dynamic o2SensorsAlt(List<Uint8List> m) => m[0].length > 2 ? m[0][2] : null;

// --------------------- ELM voltage ---------------------
Quantity? elmVoltageFromAscii(String s) {
  var v = s.toLowerCase().replaceAll('v', '').trim();
  final parsed = double.tryParse(v);
  if (parsed == null) return null;
  return Quantity(parsed, Unit.volt);
}

Quantity? elmVoltage(List<Uint8List> messages) {
  // ELM returns ASCII like "12.3V"
  final s = rawString(messages);
  return elmVoltageFromAscii(s);
}

// --------------------- PID bitmap ---------------------
Uint8List pid(List<Uint8List> m) {
  // return 4 bytes bitmap (after mode+pid) as-is
  final d = m[0].sublist(2);
  return Uint8List.fromList(d);
}


// --------------------- UAS (Units and Scaling IDs) ---------------------
Quantity? uas(List<Uint8List> m, int id) {
  // In python-OBD, UAS conversion operates on an arbitrary number of bytes.
  // Here we accept messages that have had 2 bytes of header padding added by callers.
  final d = m[0].sublist(2);
  var raw = bytesToInt(Uint8List.fromList(d));
  final def = Mode06Tables.uas[id];
  if (def == null) return null;

  if (def.unitExpr == 'bool_any') {
    final anyTrue = d.any((b) => b != 0);
    return Quantity(anyTrue ? 1.0 : 0.0, Unit.custom('bool','bool'));
  }

  return def.convert(raw, d.length * 8);
}

// --------------------- status / monitor (simplified object parity) ---------------------

class StatusTest {
  final String name;
  final bool supported;
  final bool ready;
  const StatusTest(this.name, this.supported, this.ready);
}

class StatusObject {
  bool mil = false;
  int dtcCount = 0;
  String ignitionType = 'unknown';
  final Map<String, StatusTest> tests = {};
}

final List<String> _baseTests = ['misfire', 'fuel', 'components'];
final List<String> _sparkTests = [
  'catalyst','heated_catalyst','evap_system','secondary_air_system','a_c_refrigerant',
  'oxygen_sensor','oxygen_sensor_heater','egr_system'
];
final List<String> _compressionTests = [
  'nmhc_catalyst','nox_scr_monitor','boost_pressure','exhaust_gas_sensor',
  'pm_filter','egr_vvt_system','oxygen_sensor','oxygen_sensor_heater'
];

StatusObject status(List<Uint8List> m) {
  // mirrors python-OBD logic using bit positions
  final d = m[0].sublist(2);
  final bits = BitArray(Uint8List.fromList(d));
  final out = StatusObject();
  out.mil = bits[0];
  out.dtcCount = bits.value(1, 8);
  out.ignitionType = bits[12] ? 'compression' : 'spark';

  // base tests
  for (var i = 0; i < 3; i++) {
    final name = _baseTests[2 - i];
    final supported = bits[13 + i];
    final ready = !bits[9 + i];
    out.tests[name] = StatusTest(name, supported, ready);
  }

  final tests = bits[12] ? _compressionTests : _sparkTests;
  for (var i = 0; i < 8; i++) {
    final name = tests[7 - i];
    final supported = bits[(2 * 8) + i];
    final ready = !bits[(3 * 8) + i];
    out.tests[name] = StatusTest(name, supported, ready);
  }
  return out;
}

class MonitorTest {
  final int tid;
  final dynamic value;
  final dynamic min;
  final dynamic max;
  final String name;
  final String desc;
  MonitorTest(this.tid, this.value, this.min, this.max, this.name, this.desc);
}

class MonitorObject {
  final List<MonitorTest> tests = [];
}

MonitorObject monitor(List<Uint8List> m) {
  // python-OBD: d = messages[0].data[1:]  (drop mode, keep MID)
  final data = m[0].sublist(1);
  final out = MonitorObject();

  final extra = data.length % 9;
  final d = extra == 0 ? data : data.sublist(0, data.length - extra);

  for (var i = 0; i + 8 < d.length; i += 9) {
    final tid = d[i + 1];
    final uasId = d[i + 2];
    final def = Mode06Tables.uas[uasId];
    if (def == null) continue;

    Quantity mk(int a, int b) {
      final raw = (a << 8) | b;
      if (def.unitExpr == 'bool_any') {
        final anyTrue = (a != 0) || (b != 0);
        return Quantity(anyTrue ? 1.0 : 0.0, Unit.custom('bool','bool'));
      }
      return def.convert(raw, 16);
    }

    final value = mk(d[i + 3], d[i + 4]);
    final min = mk(d[i + 5], d[i + 6]);
    final max = mk(d[i + 7], d[i + 8]);

    final meta = Mode06Tables.testIds[tid];
    final name = meta?.name ?? 'Unknown';
    final desc = meta?.desc ?? 'Unknown';

    out.tests.add(MonitorTest(tid, value, min, max, name, desc));
  }
  return out;
}

// --------------------- decoder registry ---------------------
DecodeFn getDecoder(String pythonName) {
  switch (pythonName) {
    case 'percent': return (m) => percent(m);
    case 'percent_centered': return (m) => percentCentered(m);
    case 'temp': return (m) => temp(m);
    case 'pressure': return (m) => pressure(m);
    case 'rpm': return (m) => rpm(m);
    case 'speed': return (m) => speed(m);
    case 'timing_advance': return (m) => timingAdvance(m);
    case 'fuel_pressure': return (m) => fuelPressure(m);
    case 'maf': return (m) => maf(m);
    case 'fuel_rate': return (m) => fuelRate(m);
    case 'abs_evap_pressure': return (m) => absEvapPressure(m);
    case 'evap_pressure': return (m) => evapPressure(m);
    case 'evap_pressure_alt': return (m) => evapPressureAlt(m);
    case 'absolute_load': return (m) => absoluteLoad(m);
    case 'sensor_voltage': return (m) => sensorVoltage(m);
    case 'inject_timing': return (m) => injectTiming(m);
    case 'max_maf': return (m) => maxMaf(m);
    case 'current_centered': return (m) => currentCentered(m);
    case 'air_status': return (m) => airStatus(m);
    case 'aux_input_status': return (m) => auxInputStatus(m);
    case 'dtc': return (m) => dtc(m);
    case 'single_dtc': return (m) => singleDtc(m);
    case 'fuel_status': return (m) => fuelStatus(m);
    case 'raw_string': return (m) => rawString(m);
    case 'cvn': return (m) => cvn(m);
    case 'elm_voltage': return (m) => elmVoltage(m);
    case 'pid': return (m) => pid(m);
    case 'obd_compliance': return (m) => obdCompliance(m);
    case 'fuel_type': return (m) => fuelType(m);
    case 'o2_sensors': return (m) => o2Sensors(m);
    case 'o2_sensors_alt': return (m) => o2SensorsAlt(m);
    case 'status': return (m) => status(m);
    case 'monitor': return (m) => monitor(m);
    case 'count': return (m) => Quantity(bytesToInt(Uint8List.fromList(m[0].sublist(2))).toDouble(), Unit.count);
    case 'drop': return (_) => null;
    case 'encoded_string(16)': return (m) => encodedString16(m);
    case 'encoded_string(17)': return (m) => encodedString17(m);
    // UAS partials
    case 'uas(0x01)': return (m) => uas(m, 0x01);
    case 'uas(0x07)': return (m) => uas(m, 0x07);
    case 'uas(0x09)': return (m) => uas(m, 0x09);
    case 'uas(0x0B)': return (m) => uas(m, 0x0B);
    case 'uas(0x12)': return (m) => uas(m, 0x12);
    case 'uas(0x16)': return (m) => uas(m, 0x16);
    case 'uas(0x19)': return (m) => uas(m, 0x19);
    case 'uas(0x1B)': return (m) => uas(m, 0x1B);
    case 'uas(0x1E)': return (m) => uas(m, 0x1E);
    case 'uas(0x25)': return (m) => uas(m, 0x25);
    case 'uas(0x27)': return (m) => uas(m, 0x27);
    case 'uas(0x34)': return (m) => uas(m, 0x34);
    default:
      return (m) => Uint8List.fromList(m.expand((e) => e).toList()); // raw bytes fallback
  }
}
