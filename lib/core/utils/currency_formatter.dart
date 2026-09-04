import 'package:intl/intl.dart';

final NumberFormat _currencyFormat =
    NumberFormat.currency(locale: 'en_US', symbol: r'$', decimalDigits: 2);

String formatCurrency(num value) => _currencyFormat.format(value);
