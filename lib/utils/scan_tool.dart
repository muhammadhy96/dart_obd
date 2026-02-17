import 'dart:typed_data';

import '../protocols/elm327.dart';
import '../protocols/protocol.dart';
import '../protocols/message.dart';
import '../utils/bit_array.dart';

/// Helper to auto-detect protocol and discover supported PIDs.
class ScanTool {
  final ELM327 elm;
  Protocol _protocol = const AutoProtocol();

  ScanTool(this.elm);

  Protocol get protocol => _protocol;

  Future<Protocol> detectProtocol() async {
    // ELM handles auto-protocol by default; we can still ask what it chose.
    final dpn = await elm.getProtocolNumber();
    // ATDPN can return like "A6" (auto + protocol 6) or "6"
    final code = dpn.replaceAll(RegExp(r'[^0-9A-F]'), '').toUpperCase();
    final chosen = code.startsWith('A') ? code.substring(1) : code;
    _protocol = _fromElmCode(chosen);
    return _protocol;
  }

  Protocol _fromElmCode(String code) {
    switch (code) {
      case '1':
        return const SAE_J1850_PWM();
      case '2':
        return const SAE_J1850_VPW();
      case '3':
        return const ISO9141_2();
      case '4':
        return const KWP2000_5BAUD();
      case '5':
        return const KWP2000_FAST();
      case '6':
        return const ISO15765_4_CAN_11bit_500k();
      case '7':
        return const ISO15765_4_CAN_29bit_500k();
      case '8':
        return const ISO15765_4_CAN_11bit_250k();
      case '9':
        return const ISO15765_4_CAN_29bit_250k();
      default:
        return const AutoProtocol();
    }
  }

  /// Returns a set of supported Mode 01 PIDs by scanning 0100/0120/0140/0160.
  Future<Set<int>> getSupportedMode01Pids() async {
    final out = <int>{};
    for (final base in const [0x00, 0x20, 0x40, 0x60]) {
      final req = '01${base.toRadixString(16).padLeft(2, '0').toUpperCase()}';
      final msgs = await elm.query(req);
      final payload = _mergePayloads(msgs, expectedMode: 0x41, expectedPid: base);
      if (payload == null || payload.length < 4) break;

      final bytes = Uint8List.fromList(payload.take(4).toList());
      final bits = BitArray(bytes);
      out.addAll(bits.supportedPids(basePid: base));
      // If "next PID support" bit (PID base+0x20?) isn't set, stop
      if (!out.contains(base + 0x20)) break;
    }
    return out;
  }

  /// Merge ECU responses: choose first matching and return data bytes excluding mode/pid.
  List<int>? _mergePayloads(List<Message> msgs, {required int expectedMode, required int expectedPid}) {
    for (final m in msgs) {
      final b = m.bytes;
      if (b.length < 2) continue;
      if (b[0] != expectedMode) continue;
      if (b[1] != expectedPid) continue;
      return b.sublist(2);
    }
    return null;
  }
}
