import 'dart:typed_data';

import '../decoders/unit.dart';

class OBDResponse<T> {
  final Uint8List rawBytes;
  final String rawString;
  final T? value;
  final Unit? unit;
  final bool isNull;
  final String? error;

  const OBDResponse({
    required this.rawBytes,
    required this.rawString,
    required this.value,
    required this.unit,
    required this.isNull,
    required this.error,
  });

  factory OBDResponse.nullResponse({
    required String rawString,
    Uint8List? rawBytes,
    String? error,
  }) {
    return OBDResponse<T>(
      rawBytes: rawBytes ?? Uint8List(0),
      rawString: rawString,
      value: null,
      unit: null,
      isNull: true,
      error: error,
    );
  }

  @override
  String toString() {
    if (isNull) return 'OBDResponse<null>(error: $error, raw: "$rawString")';
    return 'OBDResponse<$T>(value: $value ${unit?.symbol ?? ""}, raw: "$rawString")';
  }
}
