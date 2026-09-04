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
}

BurnRate calculateBurnRate(List<Subscription> subscriptions) {
  if (subscriptions.isEmpty) return BurnRate.empty;

  double monthly = 0;
  for (final s in subscriptions) {
    switch (s.billingCycle) {
      case BillingCycle.monthly:
        monthly += s.cost;
        break;
      case BillingCycle.yearly:
        monthly += s.cost / 12.0;
        break;
    }
  }
  return BurnRate(
    monthly: monthly,
    yearly: monthly * 12.0,
    count: subscriptions.length,
  );
}
