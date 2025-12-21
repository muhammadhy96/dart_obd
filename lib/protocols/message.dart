import 'dart:typed_data';

/// Parsed OBD message payload (service + pid + data bytes)
class Message {
  final String raw;
  final Uint8List bytes;

  /// On CAN this is often 0x7E8 etc; null if unknown.
  final int? header;

  const Message({required this.raw, required this.bytes, required this.header});

  @override
  String toString() => 'Message(header: ${header?.toRadixString(16)}, bytes: ${bytes.map((b)=>b.toRadixString(16).padLeft(2,"0")).join(" ")})';
}

/// ELM lines can include headers and length bytes. This helper normalizes into bytes.
class MessageParser {
  static final _hexByte = RegExp(r'^[0-9A-F]{2}$', caseSensitive: false);

  /// Parse one ELM line that is already stripped of prompt and whitespace.
  /// Accepts formats:
  /// - "41 0C 1A F8"
  /// - "7E8 04 41 0C 1A F8" (CAN with header and length)
  /// - "7E8 41 0C 1A F8" (header but no length)
  static Message? parseElmLine(String line) {
    final parts = line.trim().split(RegExp(r'\s+'));
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
      final p = parts[i].toUpperCase();
      if (!_hexByte.hasMatch(p)) continue;
      bytes.add(int.parse(p, radix: 16));
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
}
