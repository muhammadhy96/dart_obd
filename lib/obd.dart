library dart_obd;

import 'dart:async';
import 'dart:typed_data';

import 'connection/connection.dart';
import 'protocols/elm327.dart';
import 'protocols/message.dart';
import 'utils/obd_response.dart';
import 'utils/scan_tool.dart';
import 'commands/obd_command.dart';
import 'commands/pid_database.dart';

enum OBDStatus { disconnected, connecting, connected, error }

class OBD {
  final OBDConnection connection;
  final bool fast;
  final Duration timeout;

  ELM327? _elm;
  OBDStatus _status = OBDStatus.disconnected;
  String? _protocol;

  OBD({
    required this.connection,
    this.fast = true,
    this.timeout = const Duration(seconds: 5),
  });

  OBDStatus status() => _status;

  Future<void> connect() async {
    _status = OBDStatus.connecting;
    await connection.connect();
    _elm = ELM327(connection, timeout: timeout);

    // Init sequence similar to python-OBD defaults (conservative)
    try {
      await _elm!.reset();
      await _elm!.setEcho(false);
      await _elm!.setLinefeeds(false);
      await _elm!.setSpaces(false);
      await _elm!.setHeaders(false);
      await _elm!.setAdaptiveTiming(1);
      if (!fast) {
        await _elm!.setTimeoutMs(timeout.inMilliseconds);
      }
      // auto protocol
      await _elm!.sendAtOk('ATSP0');
      _protocol = await _elm!.getProtocolNumber();
      _status = OBDStatus.connected;
    } catch (_) {
      _status = OBDStatus.error;
      rethrow;
    }
  }

  Future<void> disconnect() async {
    _status = OBDStatus.disconnected;
    _protocol = null;
    _elm = null;
    await connection.disconnect();
  }

  String? getProtocol() => _protocol;

  /// Query by name from the built-in command DB (python-OBD parity list)
  OBDCommand commandByName(String name) => CommandDB.byName[name] ?? (throw ArgumentError('Unknown command: $name'));

  /// Equivalent to python-OBD's OBD.query(cmd)
  Future<OBDResponse> asyncQuery(OBDCommand cmd) async {
    if (_status != OBDStatus.connected || _elm == null) {
      return OBDResponse.nullResponse(rawString: '', error: 'not_connected');
    }

    final rawLines = await _elm!.send(cmd.command);

    // For AT commands, ELM returns ASCII lines; keep as raw bytes
    if (cmd.isAtCommand) {
      final ascii = rawLines.join('\n');
      final bytes = Uint8List.fromList(ascii.codeUnits);
      final value = cmd.decoder([bytes]);
      return _buildResponse(rawBytes: bytes, rawString: ascii, value: value);
    }

    // For OBD requests, parse hex frames into Message objects.
    final messages = <Message>[];
    for (final line in rawLines) {
      final msg = MessageParser.parseElmLine(line);
      if (msg != null) messages.add(msg);
    }

    if (messages.isEmpty) {
      return OBDResponse.nullResponse(rawString: rawLines.join('\n'), error: 'no_messages');
    }

    // Decode using python-decoder parity (expects list of full message bytes)
    final messageBytes = messages.map((m) => m.bytes).toList(growable: false);
    final raw = Uint8List.fromList(messageBytes.expand((e) => e).toList(growable: false));
    dynamic value;
    try {
      value = cmd.decoder(messageBytes);
    } catch (_) {
      return OBDResponse.nullResponse(rawString: rawLines.join('\n'), rawBytes: raw, error: 'decode_error');
    }

    return _buildResponse(rawBytes: raw, rawString: rawLines.join('\n'), value: value);
  }

  /// Scan Mode 01 supported PIDs using the standard bitmasks 00/20/40/60.
  Future<Set<String>> getSupportedPIDs() async {
    if (_elm == null) return <String>{};
    final scan = ScanTool(_elm!);
    final pids = await scan.getSupportedMode01Pids();
    return pids
        .map((pid) => pid.toRadixString(16).padLeft(2, '0').toUpperCase())
        .toSet();
  }

  /// Convenience: query by name
  Future<OBDResponse> queryName(String name) => asyncQuery(commandByName(name));

  OBDResponse _buildResponse({
    required Uint8List rawBytes,
    required String rawString,
    required dynamic value,
  }) {
    return OBDResponse(
      rawBytes: rawBytes,
      rawString: rawString,
      value: value,
      unit: null,
      isNull: value == null,
      error: null,
    );
  }
}
