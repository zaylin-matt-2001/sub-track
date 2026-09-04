import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/subscription.dart';
import '../../domain/usecases/add_subscription.dart';
import '../../domain/usecases/calculate_burn_rate.dart';
import '../../domain/usecases/delete_subscription.dart';
import '../../domain/usecases/get_upcoming_bills.dart';
import '../../domain/usecases/update_subscription.dart';
import 'providers.dart';
import 'subscriptions_state.dart';

class SubscriptionNotifier extends AsyncNotifier<SubscriptionsState> {
  List<Subscription> _current = const <Subscription>[];

  @override
  Future<SubscriptionsState> build() async {
    final repo = ref.read(subscriptionRepositoryProvider);
    final all = await repo.getAll();
    _current = all;
    return SubscriptionsState.from(all);
  }

  Future<void> addSubscription(Subscription subscription) async {
    final repo = ref.read(subscriptionRepositoryProvider);
    try {
      final saved = await AddSubscription(repo)(subscription);
      _current = [..._current, saved];
      state = AsyncData(_recompute(_current));
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
      state = AsyncData(_recompute(_current));
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
      return SubscriptionsState.from(all);
    });
  }

  Future<void> deleteSubscription(int id) async {
    final repo = ref.read(subscriptionRepositoryProvider);
    try {
      await DeleteSubscription(repo)(id);
      _current = _current.where((s) => s.id != id).toList(growable: false);
      state = AsyncData(_recompute(_current));
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  SubscriptionsState _recompute(List<Subscription> list) {
    final sorted = getUpcomingBills(list);
    final burn = calculateBurnRate(list);
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
