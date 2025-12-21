import '../decoders/python_obd_decoders.dart';

class OBDCommand {
  final String name;
  final String description;

  /// For OBD service requests, this is like "010C" (mode+pid).
  /// For AT / ELM commands, it can be like "ATI" or "ATRV".
  final String command;

  /// Expected bytes in python-OBD (0 means variable / no fixed length)
  final int expectedBytes;

  /// python-OBD decoder function name (e.g. 'rpm', 'percent', 'dtc', 'uas(0x16)')
  final String decoderName;

  /// True if this should be sent as an ELM AT command
  final bool isAtCommand;

  const OBDCommand({
    required this.name,
    required this.description,
    required this.command,
    required this.expectedBytes,
    required this.decoderName,
    this.isAtCommand = false,
  });

  DecodeFn get decoder => getDecoder(decoderName);

  String get mode => isAtCommand ? 'AT' : (command.length >= 2 ? command.substring(0, 2) : command);
  String? get pid => (!isAtCommand && command.length == 4) ? command.substring(2, 4) : null;
}
