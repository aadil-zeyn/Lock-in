import '../database/enums.dart';

const double kgPerLb = 0.45359237;
const double cmPerInch = 2.54;

double kgToDisplay(double kg, WeightUnit unit) =>
    unit == WeightUnit.kg ? kg : kg / kgPerLb;

double displayToKg(double value, WeightUnit unit) =>
    unit == WeightUnit.kg ? value : value * kgPerLb;

double cmToDisplay(double cm, LengthUnit unit) =>
    unit == LengthUnit.cm ? cm : cm / cmPerInch;

double displayToCm(double value, LengthUnit unit) =>
    unit == LengthUnit.cm ? value : value * cmPerInch;

String unitLabel(WeightUnit unit) => unit == WeightUnit.kg ? 'kg' : 'lb';

String lengthLabel(LengthUnit unit) => unit == LengthUnit.cm ? 'cm' : 'in';

/// "22.5", "20", "102.25" — trims trailing zeros, max 2 decimals.
String formatNumber(double value) {
  final rounded = (value * 100).round() / 100;
  if (rounded == rounded.roundToDouble()) return rounded.toInt().toString();
  var s = rounded.toStringAsFixed(2);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}
