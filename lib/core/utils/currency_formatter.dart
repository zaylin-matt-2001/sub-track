import 'package:intl/intl.dart';

/// Formats an amount in the currently selected three-letter currency code.
///
/// Amounts deliberately retain two decimal places: the app's stored costs and
/// burn-rate calculations have that display contract, including for currencies
/// that are commonly displayed without fractional units.
String formatCurrency(num value, {String currencyCode = 'USD'}) {
  final code = currencyCode.trim().toUpperCase();
  return NumberFormat.currency(
    locale: 'en_US',
    name: code,
    symbol: code == 'USD' ? r'$' : '$code ',
    decimalDigits: 2,
  ).format(value);
}
