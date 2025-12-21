class Unit {
  final String name;
  final String symbol;
  final double Function(double value, Unit to) convert;
  const Unit._(this.name, this.symbol, this.convert);

  static double _same(double v, Unit to) => v;

  // Dimensionless
  static const Unit count = Unit._('count', 'count', _same);
  static const Unit percent = Unit._('percent', '%', _same);
  static const Unit ratio = Unit._('ratio', '', _same);

  // Speed
  static const Unit kph = Unit._('kilometers_per_hour', 'km/h', _speed);
  static const Unit mph = Unit._('miles_per_hour', 'mph', _speed);

  // Temperature
  static const Unit celsius = Unit._('celsius', '°C', _temp);
  static const Unit fahrenheit = Unit._('fahrenheit', '°F', _temp);

  // Pressure
  static const Unit pascal = Unit._('pascal', 'Pa', _pressure);
  static const Unit kilopascal = Unit._('kilopascal', 'kPa', _pressure);
  static const Unit psi = Unit._('psi', 'psi', _pressure);

  // Voltage/current/resistance
  static const Unit volt = Unit._('volt', 'V', _same);
  static const Unit millivolt = Unit._('millivolt', 'mV', _same);
  static const Unit ampere = Unit._('ampere', 'A', _same);
  static const Unit milliampere = Unit._('milliampere', 'mA', _same);
  static const Unit ohm = Unit._('ohm', 'Ω', _same);
  static const Unit kiloohm = Unit._('kiloohm', 'kΩ', _same);

  // Time / distance / freq
  static const Unit second = Unit._('second', 's', _same);
  static const Unit minute = Unit._('minute', 'min', _time);
  static const Unit hour = Unit._('hour', 'h', _time);
  static const Unit millisecond = Unit._('millisecond', 'ms', _same);
  static const Unit kilometer = Unit._('kilometer', 'km', _distance);
  static const Unit mile = Unit._('mile', 'mi', _distance);
  static const Unit hertz = Unit._('hertz', 'Hz', _same);
  static const Unit millihertz = Unit._('millihertz', 'mHz', _same);

  // Engine / mass / volume flow / angles
  static const Unit rpm = Unit._('rpm', 'rpm', _same);
  static const Unit degree = Unit._('degree', '°', _same);
  static const Unit gps = Unit._('grams_per_second', 'g/s', _same);
  static const Unit liters_per_hour = Unit._('liters_per_hour', 'L/h', _same);

  /// Create a runtime unit for composite/rare units (Mode 06 UnitsAndScaling parity)
  static Unit custom(String name, String symbol) => Unit._(name, symbol, _same);

  static double _speed(double v, Unit to) {
    if (to == kph) return v;
    if (to == mph) return v * 0.621371;
    return v;
  }

  static double _temp(double v, Unit to) {
    if (to == celsius) return v;
    if (to == fahrenheit) return (v * 9.0 / 5.0) + 32.0;
    return v;
  }

  static double _pressure(double v, Unit to) {
    // stored in Pa for pascal, in kPa for kilopascal
    if (to == pascal) return v;
    if (to == kilopascal) return v / 1000.0;
    if (to == psi) return (v / 1000.0) * 0.1450377377;
    return v;
  }

  static double _time(double v, Unit to) {
    if (to == minute) return v / 60.0;
    if (to == hour) return v / 3600.0;
    return v;
  }

  static double _distance(double v, Unit to) {
    if (to == kilometer) return v;
    if (to == mile) return v * 0.621371;
    return v;
  }
}

class Quantity {
  final double value;
  final Unit unit;
  const Quantity(this.value, this.unit);

  Quantity to(Unit toUnit) {
    if (unit == toUnit) return this;
    final converted = unit.convert(value, toUnit);
    return Quantity(converted, toUnit);
  }

  @override
  String toString() => '${value.toStringAsFixed(3)} ${unit.symbol}';
}
