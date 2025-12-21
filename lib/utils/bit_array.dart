import 'dart:typed_data';

/// Minimal bit-array helper for J1979 supported PID bitfields.
class BitArray {
  final Uint8List bytes;
  BitArray(this.bytes);

  int get length => bytes.length * 8;

  bool operator [](int index) => getBit(index);

  bool getBit(int index) {
    if (index < 0) throw RangeError.range(index, 0, null, 'index');
    final byteIndex = index ~/ 8;
    final bitIndex = 7 - (index % 8); // MSB-first per OBD supported-PID maps
    if (byteIndex >= bytes.length) return false;
    return ((bytes[byteIndex] >> bitIndex) & 0x01) == 1;
  }

  int value(int start, int count) {
    if (count <= 0) return 0;
    var v = 0;
    for (var i = 0; i < count; i++) {
      v = (v << 1) | (getBit(start + i) ? 1 : 0);
    }
    return v;
  }

  BitArray slice(int start, int count) {
    if (count <= 0) return BitArray(Uint8List(0));
    final out = Uint8List((count + 7) ~/ 8);
    for (var i = 0; i < count; i++) {
      if (!getBit(start + i)) continue;
      final byteIndex = i ~/ 8;
      final bitIndex = 7 - (i % 8);
      out[byteIndex] |= (1 << bitIndex);
    }
    return BitArray(out);
  }

  List<int> indexesWhereSet() {
    final out = <int>[];
    for (var i = 0; i < length; i++) {
      if (getBit(i)) out.add(i);
    }
    return out;
  }

  /// Supported PID map for a [basePid] block (00,20,40,60,80).
  /// For PID 00 response: bits represent PIDs 01..20.
  List<int> supportedPids({required int basePid}) {
    final out = <int>[];
    for (var i = 1; i <= bytes.length * 8; i++) {
      if (getBit(i - 1)) out.add(basePid + i);
    }
    return out;
  }
}
