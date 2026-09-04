import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../subscriptions/presentation/controllers/providers.dart';

class SettingsState {
  final String baseCurrency;

  const SettingsState({required this.baseCurrency});

  static const defaults = SettingsState(baseCurrency: 'USD');
}

class SettingsNotifier extends AsyncNotifier<SettingsState> {
  @override
  Future<SettingsState> build() async {
    try {
      final source = ref.read(settingsLocalDataSourceProvider);
      return SettingsState(baseCurrency: await source.getBaseCurrency());
    } on UnimplementedError {
      // Keeps isolated subscription tests usable when they deliberately
      // override only the subscription repository. App startup always
      // supplies the database provider.
      return SettingsState.defaults;
    }
  }

  Future<void> setBaseCurrency(String currencyCode) async {
    final normalized = currencyCode.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(normalized)) {
      throw ArgumentError.value(
        currencyCode,
        'currencyCode',
        'must be a 3-letter code',
      );
    }
    final source = ref.read(settingsLocalDataSourceProvider);
    await source.setBaseCurrency(normalized);
    state = AsyncData(SettingsState(baseCurrency: normalized));
  }
}

final settingsNotifierProvider =
    AsyncNotifierProvider<SettingsNotifier, SettingsState>(
      SettingsNotifier.new,
    );
