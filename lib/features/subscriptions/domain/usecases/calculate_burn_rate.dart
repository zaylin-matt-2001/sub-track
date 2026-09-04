import '../../../../core/constants/enums.dart';
import '../entities/subscription.dart';

class BurnRate {
  final double monthly;
  final double yearly;
  final int count;

  const BurnRate({
    required this.monthly,
    required this.yearly,
    required this.count,
  });

  static const empty = BurnRate(monthly: 0, yearly: 0, count: 0);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BurnRate &&
        other.monthly == monthly &&
        other.yearly == yearly &&
        other.count == count;
  }

  @override
  int get hashCode => Object.hash(monthly, yearly, count);
}

BurnRate calculateBurnRate(
  List<Subscription> subscriptions, {
  Map<String, double> exchangeRates = const <String, double>{},
  String baseCurrency = 'USD',
}) {
  if (subscriptions.isEmpty) return BurnRate.empty;

  double monthly = 0;
  int activeCount = 0;
  for (final s in subscriptions) {
    if (!s.isActive) continue;
    activeCount++;
    final rate = s.currencyCode.toUpperCase() == baseCurrency.toUpperCase()
        ? 1.0
        : exchangeRates[s.currencyCode.toUpperCase()] ?? 1.0;
    switch (s.billingCycle) {
      case BillingCycle.monthly:
        monthly += s.cost * rate;
        break;
      case BillingCycle.yearly:
        monthly += (s.cost / 12.0) * rate;
        break;
    }
  }
  return BurnRate(monthly: monthly, yearly: monthly * 12.0, count: activeCount);
}
