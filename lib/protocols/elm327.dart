import 'dart:async';

import '../connection/obd_connection.dart';
import '../utils/exceptions.dart';
import 'message.dart';

/// ELM327 command + response handling.
/// This class is transport-agnostic and relies on [OBDConnection] for IO.
class ELM327 {
  final OBDConnection connection;

  /// ELM prompt is typically ">".
  final String prompt;

  /// Response timeout per request.
  final Duration timeout;

  /// When true, strips common noise lines such as "SEARCHING...".
  final bool filterNoise;

  ELM327(
    this.connection, {
    this.prompt = '>',
    this.timeout = const Duration(seconds: 2),
    this.filterNoise = true,
  });

  static const List<String> initSequence = [
    'ATZ', // reset
    'ATE0', // echo off
    'ATL0', // linefeeds off
    'ATS0', // spaces off
    'ATH1', // headers on (helps with multi-ECU)
    'ATSP0', // auto protocol
  ];

  /// Send an AT or OBD request string, return raw text lines (without prompt).
  Future<List<String>> send(String cmd) async {
    if (!connection.isConnected) throw OBDNotConnectedException();
    final normalized = cmd.trim().toUpperCase();
    await connection.write('$normalized\r');

    final lines = <String>[];
    final completer = Completer<List<String>>();

    late StreamSubscription<String> sub;
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        sub.cancel();
        completer.completeError(OBDTimeoutException('Timeout waiting for ELM response to $normalized'));
      }
    });

    sub = connection.lines.listen((chunk) {
      // Connection gives us already line-split text; still guard
      final line = chunk.replaceAll('\r', '').replaceAll('\n', '').trim();
      if (line.isEmpty) return;

      if (line == prompt) {
        if (!completer.isCompleted) completer.complete(lines);
        return;
      }

      // Some transports do not emit prompt as separate line; detect end by trailing '>'
      if (line.endsWith(prompt) && line.length > 1) {
        final before = line.substring(0, line.length - 1).trim();
        if (before.isNotEmpty) lines.add(before);
        if (!completer.isCompleted) completer.complete(lines);
        return;
      }

      if (line == normalized) {
        // Echoed request (if echo on); ignore
        return;
      }

      if (filterNoise) {
        final upper = line.toUpperCase();
        if (upper.startsWith('SEARCHING')) return;
        if (upper.startsWith('BUS INIT')) return;
        if (upper == 'STOPPED') {
          // ELM "STOPPED" can appear if user interrupted; treat as error
          if (!completer.isCompleted) {
            completer.completeError(OBDResponseException('ELM reported STOPPED'));
          }
          return;
        }
      }

      lines.add(line);
    });

    try {
      final result = await completer.future;
      return result;
    } finally {
      timer.cancel();
      await sub.cancel();
    }
  }

  Future<void> initialize() async {
    for (final cmd in initSequence) {
      await sendAtOk(cmd);
    }
  }

  Future<void> reset() => sendAtOk('ATZ');

  Future<void> sendAtOk(String cmd) async {
    final lines = await send(cmd);
    if (lines.isEmpty) throw OBDResponseException('Empty response to $cmd');
    final ok = lines.any((l) => l.trim().toUpperCase() == 'OK');
    if (!ok && cmd.toUpperCase().startsWith('ATZ')) {
      // Reset might respond with version string; allow.
      return;
    }
    if (!ok) {
      final joined = lines.join(' | ');
      throw OBDResponseException('Expected OK for $cmd, got: $joined');
    }
  }

  /// Send an OBD request (e.g. "010C"), return parsed messages.
  Future<List<Message>> query(String request) async {
    final lines = await send(request);
    if (lines.isEmpty) {
      throw OBDResponseException('Empty response to $request');
    }

    // Handle explicit ELM error lines
    final upperJoined = lines.map((e) => e.toUpperCase()).join(' | ');
    if (upperJoined.contains('NO DATA')) {
      return const [];
    }
    if (upperJoined.contains('UNABLE TO CONNECT')) {
      throw OBDConnectionException('Unable to connect (ELM)');
    }
    if (upperJoined.contains('?')) {
      throw OBDProtocolException('ELM did not understand command: $request');
    }

    final msgs = <Message>[];
    for (final line in lines) {
      final m = MessageParser.parseElmLine(_spaceHex(line));
      if (m != null) msgs.add(m);
    }
    return msgs;
  }

  String _spaceHex(String s) {
    // If spaces are disabled, ELM replies like "410C1AF8".
    final t = s.replaceAll(' ', '').toUpperCase();
    if (t.length <= 2) return s;
    // Preserve headers like "7E8"
    final parts = s.trim().split(RegExp(r'\s+'));
    if (parts.isNotEmpty && (parts[0].length == 3 || parts[0].length == 4) && parts.length > 1) {
      // Already spaced with header
      return s;
    }
    // Otherwise space every 2 chars.
    final buf = StringBuffer();
    for (var i = 0; i < t.length; i += 2) {
      if (i > 0) buf.write(' ');
      buf.write(t.substring(i, (i + 2).clamp(0, t.length)));
    }
    return buf.toString();
  }

  /// Ask ELM for current protocol description number (ATDPN).
  
  // === Common AT helpers (subset of ELM327 docs) ===
  Future<void> setEcho(bool on) => sendAtOk(on ? 'ATE1' : 'ATE0');
  Future<void> setLinefeeds(bool on) => sendAtOk(on ? 'ATL1' : 'ATL0');
  Future<void> setSpaces(bool on) => sendAtOk(on ? 'ATS1' : 'ATS0');
  Future<void> setHeaders(bool on) => sendAtOk(on ? 'ATH1' : 'ATH0');
  Future<void> setAdaptiveTiming(int mode) => sendAtOk('ATAT$mode'); // 0..2
  Future<void> setTimeoutMs(int ms) async {
    final v = (ms / 4.0).round().clamp(0, 255);
    await sendAtOk('ATST${v.toRadixString(16).padLeft(2,'0').toUpperCase()}');
  }
  Future<void> setProtocol(String elmCode) => sendAtOk('ATSP$elmCode');
  Future<String> identify() async {
    final lines = await send('ATI');
    return lines.join(' ').trim();
  }

  Future<String> getProtocolNumber() async {

    final lines = await send('ATDPN');
    return lines.isEmpty ? '' : lines.last.trim();
  }
}
