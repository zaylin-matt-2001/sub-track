import '../../domain/entities/subscription.dart';
import '../../domain/usecases/calculate_burn_rate.dart';
import '../../domain/usecases/get_upcoming_bills.dart';

class SubscriptionsState {
  final List<Subscription> subscriptions;
  final double monthlyBurnRate;
  final double yearlyBurnRate;
  final int count;
  final String baseCurrency;
  final Map<String, double> exchangeRates;

  const SubscriptionsState({
    required this.subscriptions,
    required this.monthlyBurnRate,
    required this.yearlyBurnRate,
    required this.count,
    this.baseCurrency = 'USD',
    this.exchangeRates = const <String, double>{},
  });

  static const empty = SubscriptionsState(
    subscriptions: <Subscription>[],
    monthlyBurnRate: 0,
    yearlyBurnRate: 0,
    count: 0,
    baseCurrency: 'USD',
  );

  factory SubscriptionsState.from(
    List<Subscription> subscriptions, {
    Map<String, double> exchangeRates = const <String, double>{},
    String baseCurrency = 'USD',
  }) {
    final sorted = getUpcomingBills(subscriptions);
    final burn = calculateBurnRate(
      subscriptions,
      exchangeRates: exchangeRates,
      baseCurrency: baseCurrency,
    );
    return SubscriptionsState(
      subscriptions: sorted,
      monthlyBurnRate: burn.monthly,
      yearlyBurnRate: burn.yearly,
      count: burn.count,
      baseCurrency: baseCurrency.toUpperCase(),
      exchangeRates: Map.unmodifiable(exchangeRates),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SubscriptionsState &&
        other.monthlyBurnRate == monthlyBurnRate &&
        other.yearlyBurnRate == yearlyBurnRate &&
        other.count == count &&
        other.baseCurrency == baseCurrency &&
        _mapEqual(other.exchangeRates, exchangeRates) &&
        _listEqual(other.subscriptions, subscriptions);
  }

  @override
  int get hashCode => Object.hash(
    monthlyBurnRate,
    yearlyBurnRate,
    count,
    baseCurrency,
    Object.hashAll(exchangeRates.entries),
    Object.hashAll(subscriptions),
  );

  static bool _listEqual(List<Subscription> a, List<Subscription> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _mapEqual(Map<String, double> a, Map<String, double> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}
