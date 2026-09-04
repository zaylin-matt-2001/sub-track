import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/subscription.dart';
import '../../domain/usecases/add_subscription.dart';
import '../../domain/usecases/calculate_burn_rate.dart';
import '../../domain/usecases/delete_subscription.dart';
import '../../domain/usecases/get_upcoming_bills.dart';
import '../../domain/usecases/update_subscription.dart';
import '../../../settings/presentation/controllers/exchange_rate_notifier.dart';
import '../../../settings/presentation/controllers/settings_notifier.dart';
import 'providers.dart';
import 'subscriptions_state.dart';

class SubscriptionNotifier extends AsyncNotifier<SubscriptionsState> {
  List<Subscription> _current = const <Subscription>[];

  @override
  Future<SubscriptionsState> build() async {
    // Observe persisted conversion inputs without rebuilding this notifier.
    // This keeps an in-flight add/edit/delete operation intact while settings
    // are first loaded or subsequently saved.
    ref.listen(settingsNotifierProvider, (_, _) => _emitRecomputedIfReady());
    ref.listen(
      exchangeRateNotifierProvider,
      (_, _) => _emitRecomputedIfReady(),
    );
    final settings =
        ref.read(settingsNotifierProvider).valueOrNull ??
        SettingsState.defaults;
    final exchangeRates =
        ref.read(exchangeRateNotifierProvider).valueOrNull ??
        const <String, double>{};
    final repo = ref.read(subscriptionRepositoryProvider);
    final all = await repo.getAll();
    _current = all;
    return _recompute(all, settings.baseCurrency, exchangeRates);
  }

  Future<void> addSubscription(Subscription subscription) async {
    final repo = ref.read(subscriptionRepositoryProvider);
    try {
      final saved = await AddSubscription(repo)(subscription);
      _current = [..._current, saved];
      state = AsyncData(_recomputeWithCurrentSettings(_current));
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> updateSubscription(Subscription subscription) async {
    final repo = ref.read(subscriptionRepositoryProvider);
    try {
      await UpdateSubscription(repo)(subscription);
      _current = [
        for (final s in _current)
          if (s.id == subscription.id) subscription else s,
      ];
      state = AsyncData(_recomputeWithCurrentSettings(_current));
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(subscriptionRepositoryProvider);
      final all = await repo.getAll();
      _current = all;
      return _recomputeWithCurrentSettings(all);
    });
  }

  Future<void> deleteSubscription(int id) async {
    final repo = ref.read(subscriptionRepositoryProvider);
    try {
      await DeleteSubscription(repo)(id);
      _current = _current.where((s) => s.id != id).toList(growable: false);
      state = AsyncData(_recomputeWithCurrentSettings(_current));
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  SubscriptionsState _recomputeWithCurrentSettings(List<Subscription> list) {
    final settings =
        ref.read(settingsNotifierProvider).valueOrNull ??
        SettingsState.defaults;
    final exchangeRates =
        ref.read(exchangeRateNotifierProvider).valueOrNull ??
        const <String, double>{};
    return _recompute(list, settings.baseCurrency, exchangeRates);
  }

  void _emitRecomputedIfReady() {
    if (!state.hasValue) return;
    state = AsyncData(_recomputeWithCurrentSettings(_current));
  }

  SubscriptionsState _recompute(
    List<Subscription> list,
    String baseCurrency,
    Map<String, double> exchangeRates,
  ) {
    final sorted = getUpcomingBills(list);
    final burn = calculateBurnRate(
      list,
      exchangeRates: exchangeRates,
      baseCurrency: baseCurrency,
    );
    return SubscriptionsState(
      subscriptions: sorted,
      monthlyBurnRate: burn.monthly,
      yearlyBurnRate: burn.yearly,
      count: burn.count,
    );
  }
}

final subscriptionNotifierProvider =
    AsyncNotifierProvider<SubscriptionNotifier, SubscriptionsState>(
      SubscriptionNotifier.new,
    );
