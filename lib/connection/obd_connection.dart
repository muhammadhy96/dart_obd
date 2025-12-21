import 'dart:async';

/// Transport abstraction for ELM-like adapters.
/// Implementations must:
/// - connect/disconnect
/// - write raw strings (including \r)
/// - expose a stream of text lines (without blocking)
abstract class OBDConnection {
  bool get isConnected;

  /// Emits *lines* of ASCII from the adapter (no guarantee about prompt).
  Stream<String> get lines;

  Future<void> connect();
  Future<void> disconnect();

  Future<void> write(String data);
}

/// Simple connection state snapshot
class ConnectionStatus {
  final bool connected;
  final String? details;
  const ConnectionStatus({required this.connected, this.details});
}
