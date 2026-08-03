import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formats digit-only input with thousands separators (e.g. `1234567` →
/// `1,234,567`) while keeping the caret at a sensible position.
///
/// The formatter strips any non-digit characters itself, so it must be used
/// on its own (do NOT combine it with
/// [FilteringTextInputFormatter.digitsOnly], which would remove the grouping
/// commas it adds). When reading the field value back, strip the separators
/// with [ThousandsSeparatorInputFormatter.digitsOnly] before parsing.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  ThousandsSeparatorInputFormatter({this.maxDigits});

  /// Optional cap on the number of digits (grouping separators excluded).
  final int? maxDigits;

  static final NumberFormat _formatter = NumberFormat('#,###');

  /// Removes grouping separators so callers can parse the raw integer.
  static String digitsOnly(String value) =>
      value.replaceAll(RegExp(r'[^0-9]'), '');

  /// Formats an integer with grouping separators. Useful for prefilling a
  /// controller so the initial value matches the live formatting.
  static String format(int value) => _formatter.format(value);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = digitsOnly(newValue.text);
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }
    if (maxDigits != null && digits.length > maxDigits!) {
      // Reject the edit and keep the previous (valid) value.
      return oldValue;
    }

    final formatted = _formatter.format(int.parse(digits));

    // Preserve the caret: place it after the same number of digits that
    // preceded it in the raw input.
    final rawCaret = newValue.selection.end.clamp(0, newValue.text.length);
    final digitsBeforeCaret =
        digitsOnly(newValue.text.substring(0, rawCaret)).length;
    var caret = 0;
    var seenDigits = 0;
    while (caret < formatted.length && seenDigits < digitsBeforeCaret) {
      if (_isDigit(formatted.codeUnitAt(caret))) {
        seenDigits++;
      }
      caret++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: caret),
    );
  }

  static bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;
}
