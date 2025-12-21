import 'unit.dart';

class TestId {
  final String name;
  final String desc;
  const TestId({required this.name, required this.desc});
}

class UASDef {
  final bool signed;
  final double scale;
  final double offset;
  final String unitExpr; // pint-like expression, e.g. 'kilopascal' or 'millivolt / millisecond'
  const UASDef({required this.signed, required this.scale, required this.offset, required this.unitExpr});

  Quantity convert(int raw, int bits) {
    var v = raw;
    if (signed) {
      // two's complement
      final signBit = 1 << (bits - 1);
      if ((v & signBit) != 0) {
        v = v - (1 << bits);
      }
    }
    final dv = (v * scale) + offset;
    return Quantity(dv, UnitX.fromExpr(unitExpr));
  }
}

class UnitX {
  static Unit fromExpr(String expr) {
    switch (expr) {
      case 'count': return Unit.count;
      case 'kph': return Unit.kph;
      case 'rpm': return Unit.rpm;
      case 'millivolt': return Unit.millivolt;
      case 'volt': return Unit.volt;
      case 'milliampere': return Unit.milliampere;
      case 'ampere': return Unit.ampere;
      case 'millisecond': return Unit.millisecond;
      case 'second': return Unit.second;
      case 'milliohm': return Unit.custom('milliohm','mΩ');
      case 'ohm': return Unit.ohm;
      case 'kiloohm': return Unit.kiloohm;
      case 'celsius': return Unit.celsius;
      case 'kilopascal': return Unit.kilopascal;
      case 'pascal': return Unit.pascal;
      case 'degree': return Unit.degree;
      case 'ratio': return Unit.ratio;
      case 'millihertz': return Unit.millihertz;
      case 'hertz': return Unit.hertz;
      case 'kilohertz': return Unit.custom('kilohertz','kHz');
      case 'kilometer': return Unit.kilometer;
      case 'grams_per_second': return Unit.gps;
      case 'percent': return Unit.percent;
      case 'liter': return Unit.custom('liter','L');
      case 'inch': return Unit.custom('inch','in');
      case 'minute': return Unit.minute;
      case 'microsecond': return Unit.custom('microsecond','µs');
      case 'microampere': return Unit.custom('microampere','µA');
      case 'ppm': return Unit.custom('ppm','ppm');
      default:
        // composites / powers (e.g., 'millivolt / millisecond', 'millimeter ** 2')
        return Unit.custom(expr, expr);
    }
  }
}

class Mode06Tables {
  static const Map<int, TestId> testIds = {
  0x01: TestId(name: 'RTL_THRESHOLD_VOLTAGE', desc: 'Rich to lean sensor threshold voltage'),
  0x02: TestId(name: 'LTR_THRESHOLD_VOLTAGE', desc: 'Lean to rich sensor threshold voltage'),
  0x03: TestId(name: 'LOW_VOLTAGE_SWITCH_TIME', desc: 'Low sensor voltage for switch time calculation'),
  0x04: TestId(name: 'HIGH_VOLTAGE_SWITCH_TIME', desc: 'High sensor voltage for switch time calculation'),
  0x05: TestId(name: 'RTL_SWITCH_TIME', desc: 'Rich to lean sensor switch time'),
  0x06: TestId(name: 'LTR_SWITCH_TIME', desc: 'Lean to rich sensor switch time'),
  0x07: TestId(name: 'MIN_VOLTAGE', desc: 'Minimum sensor voltage for test cycle'),
  0x08: TestId(name: 'MAX_VOLTAGE', desc: 'Maximum sensor voltage for test cycle'),
  0x09: TestId(name: 'TRANSITION_TIME', desc: 'Time between sensor transitions'),
  0x0A: TestId(name: 'SENSOR_PERIOD', desc: 'Sensor period'),
  0x0B: TestId(name: 'MISFIRE_AVERAGE', desc: 'Average misfire counts for last ten driving cycles'),
  0x0C: TestId(name: 'MISFIRE_COUNT', desc: 'Misfire counts for last/current driving cycles'),
  };

  static const Map<int, UASDef> uas = {
  0x01: UASDef(signed: false, scale: 1.0, offset: 0.0, unitExpr: 'count'),
  0x02: UASDef(signed: false, scale: 0.1, offset: 0.0, unitExpr: 'count'),
  0x03: UASDef(signed: false, scale: 0.01, offset: 0.0, unitExpr: 'count'),
  0x04: UASDef(signed: false, scale: 0.001, offset: 0.0, unitExpr: 'count'),
  0x05: UASDef(signed: false, scale: 3.05e-05, offset: 0.0, unitExpr: 'count'),
  0x06: UASDef(signed: false, scale: 0.000305, offset: 0.0, unitExpr: 'count'),
  0x07: UASDef(signed: false, scale: 0.25, offset: 0.0, unitExpr: 'rpm'),
  0x08: UASDef(signed: false, scale: 0.01, offset: 0.0, unitExpr: 'kph'),
  0x09: UASDef(signed: false, scale: 1.0, offset: 0.0, unitExpr: 'kph'),
  0x0A: UASDef(signed: false, scale: 0.122, offset: 0.0, unitExpr: 'millivolt'),
  0x0B: UASDef(signed: false, scale: 0.001, offset: 0.0, unitExpr: 'volt'),
  0x0C: UASDef(signed: false, scale: 0.01, offset: 0.0, unitExpr: 'volt'),
  0x0D: UASDef(signed: false, scale: 0.00390625, offset: 0.0, unitExpr: 'milliampere'),
  0x0E: UASDef(signed: false, scale: 0.001, offset: 0.0, unitExpr: 'ampere'),
  0x0F: UASDef(signed: false, scale: 0.01, offset: 0.0, unitExpr: 'ampere'),
  0x10: UASDef(signed: false, scale: 1.0, offset: 0.0, unitExpr: 'millisecond'),
  0x11: UASDef(signed: false, scale: 100.0, offset: 0.0, unitExpr: 'millisecond'),
  0x12: UASDef(signed: false, scale: 1.0, offset: 0.0, unitExpr: 'second'),
  0x13: UASDef(signed: false, scale: 1.0, offset: 0.0, unitExpr: 'milliohm'),
  0x14: UASDef(signed: false, scale: 1.0, offset: 0.0, unitExpr: 'ohm'),
  0x15: UASDef(signed: false, scale: 1.0, offset: 0.0, unitExpr: 'kiloohm'),
  0x16: UASDef(signed: false, scale: 0.1, offset: -40.0, unitExpr: 'celsius'),
  0x17: UASDef(signed: false, scale: 0.01, offset: 0.0, unitExpr: 'kilopascal'),
  0x18: UASDef(signed: false, scale: 0.0117, offset: 0.0, unitExpr: 'kilopascal'),
  0x19: UASDef(signed: false, scale: 0.079, offset: 0.0, unitExpr: 'kilopascal'),
  0x1A: UASDef(signed: false, scale: 1.0, offset: 0.0, unitExpr: 'kilopascal'),
  0x1B: UASDef(signed: false, scale: 10.0, offset: 0.0, unitExpr: 'kilopascal'),
  0x1C: UASDef(signed: false, scale: 0.01, offset: 0.0, unitExpr: 'degree'),
  0x1D: UASDef(signed: false, scale: 0.5, offset: 0.0, unitExpr: 'degree'),
  0x1E: UASDef(signed: false, scale: 3.05e-05, offset: 0.0, unitExpr: 'ratio'),
  0x1F: UASDef(signed: false, scale: 0.05, offset: 0.0, unitExpr: 'ratio'),
  0x20: UASDef(signed: false, scale: 0.00390625, offset: 0.0, unitExpr: 'ratio'),
  0x21: UASDef(signed: false, scale: 1.0, offset: 0.0, unitExpr: 'millihertz'),
  0x22: UASDef(signed: false, scale: 1.0, offset: 0.0, unitExpr: 'hertz'),
  0x23: UASDef(signed: false, scale: 1.0, offset: 0.0, unitExpr: 'kilohertz'),
  0x24: UASDef(signed: false, scale: 1.0, offset: 0.0, unitExpr: 'count'),
  0x25: UASDef(signed: false, scale: 1.0, offset: 0.0, unitExpr: 'kilometer'),
  0x26: UASDef(signed: false, scale: 0.1, offset: 0.0, unitExpr: 'millivolt / millisecond'),
  0x27: UASDef(signed: false, scale: 0.01, offset: 0.0, unitExpr: 'grams_per_second'),
  0x28: UASDef(signed: false, scale: 1.0, offset: 0.0, unitExpr: 'grams_per_second'),
  0x29: UASDef(signed: false, scale: 0.25, offset: 0.0, unitExpr: 'pascal / second'),
  0x2A: UASDef(signed: false, scale: 0.001, offset: 0.0, unitExpr: 'kilogram / hour'),
  0x2B: UASDef(signed: false, scale: 1.0, offset: 0.0, unitExpr: 'count'),
  0x2C: UASDef(signed: false, scale: 0.01, offset: 0.0, unitExpr: 'gram'),
  0x2D: UASDef(signed: false, scale: 0.01, offset: 0.0, unitExpr: 'milligram'),
  0x2E: UASDef(signed: false, scale: 1.0, offset: 0.0, unitExpr: 'bool_any'),
  0x2F: UASDef(signed: false, scale: 0.01, offset: 0.0, unitExpr: 'percent'),
  0x30: UASDef(signed: false, scale: 0.001526, offset: 0.0, unitExpr: 'percent'),
  0x31: UASDef(signed: false, scale: 0.001, offset: 0.0, unitExpr: 'liter'),
  0x32: UASDef(signed: false, scale: 3.05e-05, offset: 0.0, unitExpr: 'inch'),
  0x33: UASDef(signed: false, scale: 0.00024414, offset: 0.0, unitExpr: 'ratio'),
  0x34: UASDef(signed: false, scale: 1.0, offset: 0.0, unitExpr: 'minute'),
  0x35: UASDef(signed: false, scale: 10.0, offset: 0.0, unitExpr: 'millisecond'),
  0x36: UASDef(signed: false, scale: 0.01, offset: 0.0, unitExpr: 'gram'),
  0x37: UASDef(signed: false, scale: 0.1, offset: 0.0, unitExpr: 'gram'),
  0x38: UASDef(signed: false, scale: 1.0, offset: 0.0, unitExpr: 'gram'),
  0x39: UASDef(signed: false, scale: 0.01, offset: -327.68, unitExpr: 'percent'),
  0x3A: UASDef(signed: false, scale: 0.001, offset: 0.0, unitExpr: 'gram'),
  0x3B: UASDef(signed: false, scale: 0.0001, offset: 0.0, unitExpr: 'gram'),
  0x3C: UASDef(signed: false, scale: 0.1, offset: 0.0, unitExpr: 'microsecond'),
  0x3D: UASDef(signed: false, scale: 0.01, offset: 0.0, unitExpr: 'milliampere'),
  0x3E: UASDef(signed: false, scale: 6.103516e-05, offset: 0.0, unitExpr: 'millimeter ** 2'),
  0x3F: UASDef(signed: false, scale: 0.01, offset: 0.0, unitExpr: 'liter'),
  0x40: UASDef(signed: false, scale: 1.0, offset: 0.0, unitExpr: 'ppm'),
  0x41: UASDef(signed: false, scale: 0.01, offset: 0.0, unitExpr: 'microampere'),
  0x81: UASDef(signed: true, scale: 1.0, offset: 0.0, unitExpr: 'count'),
  0x82: UASDef(signed: true, scale: 0.1, offset: 0.0, unitExpr: 'count'),
  0x83: UASDef(signed: true, scale: 0.01, offset: 0.0, unitExpr: 'count'),
  0x84: UASDef(signed: true, scale: 0.001, offset: 0.0, unitExpr: 'count'),
  0x85: UASDef(signed: true, scale: 3.05e-05, offset: 0.0, unitExpr: 'count'),
  0x86: UASDef(signed: true, scale: 0.000305, offset: 0.0, unitExpr: 'count'),
  0x87: UASDef(signed: true, scale: 1.0, offset: 0.0, unitExpr: 'ppm'),
  0x8A: UASDef(signed: true, scale: 0.122, offset: 0.0, unitExpr: 'millivolt'),
  0x8B: UASDef(signed: true, scale: 0.001, offset: 0.0, unitExpr: 'volt'),
  0x8C: UASDef(signed: true, scale: 0.01, offset: 0.0, unitExpr: 'volt'),
  0x8D: UASDef(signed: true, scale: 0.00390625, offset: 0.0, unitExpr: 'milliampere'),
  0x8E: UASDef(signed: true, scale: 0.001, offset: 0.0, unitExpr: 'ampere'),
  0x90: UASDef(signed: true, scale: 1.0, offset: 0.0, unitExpr: 'millisecond'),
  0x96: UASDef(signed: true, scale: 0.1, offset: 0.0, unitExpr: 'celsius'),
  0x99: UASDef(signed: true, scale: 0.1, offset: 0.0, unitExpr: 'kilopascal'),
  0x9C: UASDef(signed: true, scale: 0.01, offset: 0.0, unitExpr: 'degree'),
  0x9D: UASDef(signed: true, scale: 0.5, offset: 0.0, unitExpr: 'degree'),
  0xA8: UASDef(signed: true, scale: 1.0, offset: 0.0, unitExpr: 'grams_per_second'),
  0xA9: UASDef(signed: true, scale: 0.25, offset: 0.0, unitExpr: 'pascal / second'),
  0xAD: UASDef(signed: true, scale: 0.01, offset: 0.0, unitExpr: 'milligram'),
  0xAE: UASDef(signed: true, scale: 0.1, offset: 0.0, unitExpr: 'milligram'),
  0xAF: UASDef(signed: true, scale: 0.01, offset: 0.0, unitExpr: 'percent'),
  0xB0: UASDef(signed: true, scale: 0.003052, offset: 0.0, unitExpr: 'percent'),
  0xB1: UASDef(signed: true, scale: 2.0, offset: 0.0, unitExpr: 'millivolt / second'),
  0xFC: UASDef(signed: true, scale: 0.01, offset: 0.0, unitExpr: 'kilopascal'),
  0xFD: UASDef(signed: true, scale: 0.001, offset: 0.0, unitExpr: 'kilopascal'),
  0xFE: UASDef(signed: true, scale: 0.25, offset: 0.0, unitExpr: 'pascal'),
  };
}
