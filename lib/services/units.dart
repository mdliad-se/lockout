/// Unit conversion and BMI maths.
///
/// Height is always *stored* in centimetres so every calculation has one
/// source of truth; feet/inches exist only at the input and display layer.
class Units {
  Units._();

  static const double _cmPerInch = 2.54;
  static const double _inchesPerFoot = 12.0;

  static double feetInchesToCm(int feet, double inches) =>
      (feet * _inchesPerFoot + inches) * _cmPerInch;

  /// Splits centimetres into whole feet plus remaining inches.
  ///
  /// Inches are rounded to one decimal, and a value that rounds up to a full
  /// 12" is carried into the feet so "5 ft 12 in" can never be displayed.
  static ({int feet, double inches}) cmToFeetInches(double cm) {
    final totalInches = cm / _cmPerInch;
    var feet = totalInches ~/ _inchesPerFoot;
    var inches =
        double.parse((totalInches - feet * _inchesPerFoot).toStringAsFixed(1));

    if (inches >= _inchesPerFoot) {
      feet += 1;
      inches -= _inchesPerFoot;
    }
    return (feet: feet, inches: inches);
  }

  static String formatHeight(double cm, String unit) {
    if (unit == 'ft') {
      final h = cmToFeetInches(cm);
      final inches = h.inches % 1 == 0
          ? h.inches.toStringAsFixed(0)
          : h.inches.toStringAsFixed(1);
      return '${h.feet} ft $inches in';
    }
    return '${cm.toStringAsFixed(cm % 1 == 0 ? 0 : 1)} cm';
  }

  /// Standard BMI: kg / m². Returns null for unusable inputs rather than
  /// infinity, so callers can render a dash instead of a nonsense number.
  static double? bmi({required double weightKg, required double heightCm}) {
    if (weightKg <= 0 || heightCm <= 0) return null;
    final metres = heightCm / 100.0;
    return weightKg / (metres * metres);
  }

  static String bmiCategory(double bmi) {
    if (bmi < 18.5) return 'UNDERWEIGHT';
    if (bmi < 25.0) return 'NORMAL';
    if (bmi < 30.0) return 'OVERWEIGHT';
    return 'OBESE';
  }

  static double kgToLb(double kg) => kg * 2.20462;
  static double lbToKg(double lb) => lb / 2.20462;
}
