import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../subscriptions/presentation/controllers/providers.dart';

class ExchangeRateNotifier extends AsyncNotifier<Map<String, double>> {
  @override
  Future<Map<String, double>> build() async {
    try {
      return await ref.read(settingsLocalDataSourceProvider).getExchangeRates();
    } on UnimplementedError {
      return const <String, double>{};
    }
  }

  Future<void> replaceRates(Map<String, double> rates) async {
    final normalized = <String, double>{};
    for (final entry in rates.entries) {
      final code = entry.key.trim().toUpperCase();
      if (!RegExp(r'^[A-Z]{3}$').hasMatch(code)) {
        throw ArgumentError.value(
          entry.key,
          'rates',
          'currency codes must have 3 letters',
        );
      }
      if (!entry.value.isFinite || entry.value <= 0) {
        throw ArgumentError.value(
          entry.value,
          'rates',
          'rates must be greater than zero',
        );
      }
      normalized[code] = entry.value;
    }
    await ref
        .read(settingsLocalDataSourceProvider)
        .replaceExchangeRates(normalized);
    state = AsyncData(Map.unmodifiable(normalized));
  }
}

final exchangeRateNotifierProvider =
    AsyncNotifierProvider<ExchangeRateNotifier, Map<String, double>>(
      ExchangeRateNotifier.new,
    );
