import 'package:sqflite/sqflite.dart';

/// Raw SQLite access for the singleton settings row and exchange-rate table.
class SettingsLocalDataSource {
  static const _baseCurrencyKey = 'base_currency';

  final Database _database;

  SettingsLocalDataSource(this._database);

  Future<String> getBaseCurrency() async {
    final rows = await _database.query(
      'settings',
      columns: const ['value'],
      where: 'key = ?',
      whereArgs: const [_baseCurrencyKey],
      limit: 1,
    );
    return (rows.firstOrNull?['value'] as String? ?? 'USD').toUpperCase();
  }

  Future<void> setBaseCurrency(String currencyCode) {
    return _database.insert('settings', {
      'key': _baseCurrencyKey,
      'value': currencyCode.trim().toUpperCase(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, double>> getExchangeRates() async {
    final rows = await _database.query('exchange_rates');
    return Map.unmodifiable({
      for (final row in rows)
        (row['currency_code'] as String).toUpperCase():
            (row['rate_to_base'] as num).toDouble(),
    });
  }

  /// Replaces the user-defined table atomically, so removed fields do not
  /// leave stale conversions behind.
  Future<void> replaceExchangeRates(Map<String, double> rates) async {
    await _database.transaction((txn) async {
      await txn.delete('exchange_rates');
      for (final entry in rates.entries) {
        await txn.insert('exchange_rates', {
          'currency_code': entry.key.trim().toUpperCase(),
          'rate_to_base': entry.value,
        });
      }
    });
  }
}
