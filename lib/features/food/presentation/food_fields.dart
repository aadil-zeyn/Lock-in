import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Grams typed in a form: empty means "not given", comma works as a
/// decimal point.
double? parseGrams(String text) => text.trim().isEmpty
    ? null
    : double.tryParse(text.trim().replaceAll(',', '.'));

/// "35" or "12.5" — for pre-filling number fields.
String trimNumber(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// Up to 999.9 g, one decimal.
final gramsFormatter = FilteringTextInputFormatter.allow(
  RegExp(r'^\d{0,3}([.,]\d?)?'),
);

/// Optional grams field (carbs, fat…).
class GramField extends StatelessWidget {
  const GramField({
    super.key,
    required this.controller,
    required this.label,
    this.onChanged,
    this.style,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onChanged;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textAlign: TextAlign.center,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [gramsFormatter],
      style: style,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, hintText: 'optional'),
    );
  }
}
