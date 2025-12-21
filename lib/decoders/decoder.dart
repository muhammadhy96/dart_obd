import 'dart:typed_data';
import 'unit.dart';

abstract class Decoder<T> {
  const Decoder();
  T decode(Uint8List bytes);
  Unit? get unit => null;
}

class NullDecoder extends Decoder<void> {
  const NullDecoder();
  @override
  void decode(Uint8List bytes) {}
}

class ByteDecoder extends Decoder<int> {
  const ByteDecoder();
  @override
  int decode(Uint8List bytes) => bytes.isEmpty ? -1 : bytes[0];
}

class BytesDecoder extends Decoder<Uint8List> {
  const BytesDecoder();
  @override
  Uint8List decode(Uint8List bytes) => bytes;
}

class UIntDecoder extends Decoder<int> {
  final int n;
  const UIntDecoder(this.n);
  @override
  int decode(Uint8List bytes) {
    if (bytes.length < n) return -1;
    var v = 0;
    for (var i = 0; i < n; i++) v = (v << 8) | bytes[i];
    return v;
  }
}

class LinearDecoder extends Decoder<double> {
  final int n;
  final double scale;
  final double offset;
  final Unit? _unit;
  const LinearDecoder(this.n, {required this.scale, this.offset = 0.0, Unit? unit}) : _unit = unit;

  @override
  Unit? get unit => _unit;

  @override
  double decode(Uint8List bytes) {
    if (bytes.length < n) return double.nan;
    var raw = 0;
    for (var i = 0; i < n; i++) raw = (raw << 8) | bytes[i];
    return raw * scale + offset;
  }
}

class RPMDecoder extends Decoder<double> {
  const RPMDecoder();
  @override
  Unit? get unit => Unit.rpm;
  @override
  double decode(Uint8List b) => b.length < 2 ? double.nan : ((b[0] * 256) + b[1]) / 4.0;
}

class SpeedDecoder extends Decoder<double> {
  const SpeedDecoder();
  @override
  Unit? get unit => Unit.kph;
  @override
  double decode(Uint8List b) => b.isEmpty ? double.nan : b[0].toDouble();
}

class TempDecoder extends Decoder<double> {
  const TempDecoder();
  @override
  Unit? get unit => Unit.celsius;
  @override
  double decode(Uint8List b) => b.isEmpty ? double.nan : b[0].toDouble() - 40.0;
}

class PercentDecoder extends Decoder<double> {
  const PercentDecoder();
  @override
  Unit? get unit => Unit.percent;
  @override
  double decode(Uint8List b) => b.isEmpty ? double.nan : (b[0] * 100.0) / 255.0;
}

class FuelTrimDecoder extends Decoder<double> {
  const FuelTrimDecoder();
  @override
  Unit? get unit => Unit.percent;
  @override
  double decode(Uint8List b) => b.isEmpty ? double.nan : (b[0] - 128) * (100.0 / 128.0);
}

class TimingAdvanceDecoder extends Decoder<double> {
  const TimingAdvanceDecoder();
  @override
  Unit? get unit => Unit.degree;
  @override
  double decode(Uint8List b) => b.isEmpty ? double.nan : (b[0] / 2.0) - 64.0;
}

class MafDecoder extends Decoder<double> {
  const MafDecoder();
  @override
  Unit? get unit => Unit.gps;
  @override
  double decode(Uint8List b) => b.length < 2 ? double.nan : (((b[0] * 256) + b[1]) / 100.0);
}

class KpaDecoder extends Decoder<double> {
  const KpaDecoder();
  @override
  Unit? get unit => Unit.kilopascal;
  @override
  double decode(Uint8List b) => b.isEmpty ? double.nan : b[0].toDouble();
}

class FuelPressureDecoder extends Decoder<double> {
  const FuelPressureDecoder();
  @override
  Unit? get unit => Unit.kilopascal;
  @override
  double decode(Uint8List b) => b.isEmpty ? double.nan : b[0] * 3.0;
}

class FuelRailPressureDecoder extends Decoder<double> {
  const FuelRailPressureDecoder();
  @override
  Unit? get unit => Unit.kilopascal;
  @override
  double decode(Uint8List b) => b.length < 2 ? double.nan : (((b[0] * 256) + b[1]) * 0.079);
}

class FuelRailGaugePressureDecoder extends Decoder<double> {
  const FuelRailGaugePressureDecoder();
  @override
  Unit? get unit => Unit.kilopascal;
  @override
  double decode(Uint8List b) => b.length < 2 ? double.nan : (((b[0] * 256) + b[1]) * 10.0);
}

class VoltageDecoder extends Decoder<double> {
  const VoltageDecoder();
  @override
  Unit? get unit => Unit.volt;
  @override
  double decode(Uint8List b) => b.length < 2 ? double.nan : (((b[0] * 256) + b[1]) / 1000.0);
}

class SecondsDecoder extends Decoder<double> {
  const SecondsDecoder();
  @override
  Unit? get unit => Unit.second;
  @override
  double decode(Uint8List b) => b.length < 2 ? double.nan : ((b[0] * 256) + b[1]).toDouble();
}

class DistanceKmDecoder extends Decoder<double> {
  const DistanceKmDecoder();
  @override
  Unit? get unit => Unit.kilometer;
  @override
  double decode(Uint8List b) => b.length < 2 ? double.nan : ((b[0] * 256) + b[1]).toDouble();
}

class AbsoluteLoadDecoder extends Decoder<double> {
  const AbsoluteLoadDecoder();
  @override
  Unit? get unit => Unit.percent;
  @override
  double decode(Uint8List b) => b.length < 2 ? double.nan : (((b[0] * 256) + b[1]) * 100.0) / 255.0;
}

class EquivalenceRatioDecoder extends Decoder<double> {
  const EquivalenceRatioDecoder();
  @override
  Unit? get unit => Unit.ratio;
  @override
  double decode(Uint8List b) => b.length < 2 ? double.nan : (((b[0] * 256) + b[1]) / 32768.0);
}

class EvapPressureDecoder extends Decoder<double> {
  const EvapPressureDecoder();
  @override
  Unit? get unit => Unit.kilopascal;
  @override
  double decode(Uint8List b) {
    if (b.length < 2) return double.nan;
    final pa = (((b[0] * 256) + b[1]) / 4.0) - 8192.0;
    return pa / 1000.0;
  }
}

class AbsoluteEvapPressureDecoder extends Decoder<double> {
  const AbsoluteEvapPressureDecoder();
  @override
  Unit? get unit => Unit.kilopascal;
  @override
  double decode(Uint8List b) => b.length < 2 ? double.nan : (((b[0] * 256) + b[1]) / 200.0);
}

class FuelRateDecoder extends Decoder<double> {
  const FuelRateDecoder();
  @override
  Unit? get unit => Unit.liters_per_hour;
  @override
  double decode(Uint8List b) => b.length < 2 ? double.nan : (((b[0] * 256) + b[1]) / 20.0);
}

class AsciiDecoder extends Decoder<String> {
  const AsciiDecoder();
  @override
  String decode(Uint8List b) {
    final chars = b.where((x) => x >= 0x20 && x <= 0x7E).toList(growable: false);
    return String.fromCharCodes(chars).trim();
  }
}

class DtcDecoder extends Decoder<List<String>> {
  const DtcDecoder();
  @override
  List<String> decode(Uint8List data) {
    final out = <String>[];
    for (var i = 0; i + 1 < data.length; i += 2) {
      final a = data[i];
      final b = data[i + 1];
      if (a == 0 && b == 0) continue;
      out.add(_decode(a, b));
    }
    return out;
  }

  String _decode(int a, int b) {
    final first = (a & 0xC0) >> 6;
    final letter = switch (first) { 0 => 'P', 1 => 'C', 2 => 'B', _ => 'U' };
    final d1 = (a & 0x30) >> 4;
    final d2 = (a & 0x0F);
    final d3 = (b & 0xF0) >> 4;
    final d4 = (b & 0x0F);
    String hx(int n) => n.toRadixString(16).toUpperCase();
    return '$letter$d1${hx(d2)}${hx(d3)}${hx(d4)}';
  }
}
