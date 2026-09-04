import 'package:flutter_test/flutter_test.dart';
import 'package:sub_track/core/utils/currency_formatter.dart';

void main() {
  group('formatCurrency', () {
    test('formats sub-dollar amounts to 2 dp', () {
      expect(formatCurrency(14.99), r'$14.99');
      expect(formatCurrency(0), r'$0.00');
      expect(formatCurrency(0.5), r'$0.50');
    });

    test('formats thousands with a comma separator', () {
      expect(formatCurrency(1200), r'$1,200.00');
      expect(formatCurrency(1234567.89), r'$1,234,567.89');
    });

    test('does not overflow on very large values', () {
      final formatted = formatCurrency(1e9);
      expect(formatted, startsWith(r'$'));
      expect(formatted, endsWith('.00'));
    });

    test('uses the selected base currency instead of a hard-coded dollar', () {
      expect(formatCurrency(1200, currencyCode: 'MMK'), 'MMK 1,200.00');
      expect(formatCurrency(14.99, currencyCode: 'eur'), 'EUR 14.99');
    });
  });
}
