import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/utils/thousands_separator_input_formatter.dart';

void main() {
  group('ThousandsSeparatorInputFormatter', () {
    final formatter = ThousandsSeparatorInputFormatter();

    TextEditingValue format(String text, {int? selection}) {
      final oldValue = const TextEditingValue(text: '');
      final newValue = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: selection ?? text.length),
      );
      return formatter.formatEditUpdate(oldValue, newValue);
    }

    test('groups digits at every third position from the right', () {
      expect(format('1000').text, '1,000');
      expect(format('12345').text, '12,345');
      expect(format('1234567').text, '1,234,567');
    });

    test('does not add a comma below four digits', () {
      expect(format('0').text, '0');
      expect(format('12').text, '12');
      expect(format('999').text, '999');
    });

    test('strips non-digit characters from the incoming text', () {
      // Simulates a paste of an already-formatted or noisy value.
      expect(format('1,234').text, '1,234');
      expect(format('¥1234').text, '1,234');
    });

    test('empty input yields empty text', () {
      expect(format('').text, '');
    });

    group('Edge Cases', () {
      test('leading zeros collapse to the numeric value', () {
        expect(format('007').text, '7');
      });

      test('maxDigits rejects an over-long edit and keeps the old value', () {
        final capped = ThousandsSeparatorInputFormatter(maxDigits: 3);
        final oldValue = const TextEditingValue(text: '123');
        final newValue = const TextEditingValue(text: '1234');
        expect(capped.formatEditUpdate(oldValue, newValue).text, '123');
      });

      test('caret stays after the same number of digits', () {
        // Caret after "12" in "12345" -> after "12" in "12,345" (offset 2).
        final result = format('12345', selection: 2);
        expect(result.text, '12,345');
        expect(result.selection.baseOffset, 2);
      });
    });

    group('digitsOnly / format helpers', () {
      test('digitsOnly removes separators for parsing', () {
        expect(ThousandsSeparatorInputFormatter.digitsOnly('1,234,567'),
            '1234567');
        expect(ThousandsSeparatorInputFormatter.digitsOnly('¥25,000'), '25000');
        expect(ThousandsSeparatorInputFormatter.digitsOnly(''), '');
      });

      test('format groups an integer for prefilling', () {
        expect(ThousandsSeparatorInputFormatter.format(0), '0');
        expect(ThousandsSeparatorInputFormatter.format(25000), '25,000');
        expect(ThousandsSeparatorInputFormatter.format(1234567), '1,234,567');
      });
    });
  });
}
