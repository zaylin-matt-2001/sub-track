import '../../domain/entities/subscription.dart';
import '../../domain/usecases/calculate_burn_rate.dart';
import '../../domain/usecases/get_upcoming_bills.dart';

class SubscriptionsState {
  final List<Subscription> subscriptions;
  final double monthlyBurnRate;
  final double yearlyBurnRate;
  final int count;

  const SubscriptionsState({
    required this.subscriptions,
    required this.monthlyBurnRate,
    required this.yearlyBurnRate,
    required this.count,
  });

  static const empty = SubscriptionsState(
    subscriptions: <Subscription>[],
    monthlyBurnRate: 0,
    yearlyBurnRate: 0,
    count: 0,
  );

  factory SubscriptionsState.from(List<Subscription> subscriptions) {
    final sorted = getUpcomingBills(subscriptions);
    final burn = calculateBurnRate(subscriptions);
    return SubscriptionsState(
      subscriptions: sorted,
      monthlyBurnRate: burn.monthly,
      yearlyBurnRate: burn.yearly,
      count: burn.count,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SubscriptionsState &&
        other.monthlyBurnRate == monthlyBurnRate &&
        other.yearlyBurnRate == yearlyBurnRate &&
        other.count == count &&
        _listEqual(other.subscriptions, subscriptions);
  }

  @override
  int get hashCode => Object.hash(
        monthlyBurnRate,
        yearlyBurnRate,
        count,
        Object.hashAll(subscriptions),
      );

  static bool _listEqual(List<Subscription> a, List<Subscription> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
