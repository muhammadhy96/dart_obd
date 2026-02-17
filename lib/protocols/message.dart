import 'dart:typed_data';

/// Parsed OBD message payload (service + pid + data bytes)
class Message {
  final String raw;
  final Uint8List bytes;

  /// On CAN this is often 0x7E8 etc; null if unknown.
  final int? header;

  const Message({required this.raw, required this.bytes, required this.header});

  @override
  String toString() =>
      'Message(header: ${header?.toRadixString(16)}, bytes: ${bytes.map((b) => b.toRadixString(16).padLeft(2, "0")).join(" ")})';
}

/// ELM lines can include headers and length bytes. This helper normalizes into bytes.
class MessageParser {
  static final _hexByte = RegExp(r'^[0-9A-F]{2}$', caseSensitive: false);
  static final _hexPacked = RegExp(r'^[0-9A-F]+$', caseSensitive: false);

  /// Parse one ELM line that is already stripped of prompt and whitespace.
  /// Accepts formats:
  /// - "41 0C 1A F8"
  /// - "7E8 04 41 0C 1A F8" (CAN with header and length)
  /// - "7E8 41 0C 1A F8" (header but no length)
  /// - "410C1AF8" (spaces disabled)
  /// - "7E804410C1AF8" (header + packed payload)
  static Message? parseElmLine(String line) {
    final parts = line
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return null;

    int? header;
    var start = 0;

    // Header can be 3 or 4 hex chars
    if (parts[0].length == 3 || parts[0].length == 4) {
      final h = int.tryParse(parts[0], radix: 16);
      if (h != null) {
        header = h;
        start = 1;
      }
    }

    final bytes = <int>[];
    for (var i = start; i < parts.length; i++) {
      _appendHexToken(parts[i], bytes);
    }

    // Some adapters can emit "7E804410C1AF8" as one token when spaces are off.
    if (bytes.isEmpty && parts.length == 1) {
      final single = parts.first.toUpperCase();
      if (_hexPacked.hasMatch(single)) {
        if (single.length > 4 && (single.length - 4).isEven) {
          final h = int.tryParse(single.substring(0, 4), radix: 16);
          if (h != null) {
            header ??= h;
            _appendPackedHex(single.substring(4), bytes);
          }
        }
        if (bytes.isEmpty && single.length > 3 && (single.length - 3).isEven) {
          final h = int.tryParse(single.substring(0, 3), radix: 16);
          if (h != null) {
            header ??= h;
            _appendPackedHex(single.substring(3), bytes);
          }
        }
      }
    }
    if (bytes.isEmpty) return null;

    // If CAN length byte present, drop it.
    if (header != null && bytes.isNotEmpty) {
      final len = bytes[0];
      if (len <= bytes.length - 1) {
        // Heuristic: if next byte looks like a response mode (0x40+), treat first as length.
        final next = bytes.length > 1 ? bytes[1] : -1;
        if (next >= 0x40 && next <= 0x4F) {
          bytes.removeAt(0);
        }
      }
    }

    return Message(raw: line, bytes: Uint8List.fromList(bytes), header: header);
  }

  static void _appendHexToken(String token, List<int> out) {
    final t = token.toUpperCase();
    if (_hexByte.hasMatch(t)) {
      out.add(int.parse(t, radix: 16));
      return;
    }
    _appendPackedHex(t, out);
  }

  static void _appendPackedHex(String token, List<int> out) {
    if (!_hexPacked.hasMatch(token) || token.length.isOdd) return;
    for (var i = 0; i < token.length; i += 2) {
      out.add(int.parse(token.substring(i, i + 2), radix: 16));
    }
  }
}
