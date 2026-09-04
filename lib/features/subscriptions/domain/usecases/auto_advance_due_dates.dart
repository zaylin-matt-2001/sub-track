import '../../../../core/constants/enums.dart';
import '../entities/subscription.dart';

/// Advances past-due subscriptions one billing cycle at a time.
///
/// This is deliberately pure: persistence is owned by [SubscriptionNotifier].
/// Dart's [DateTime] constructor supplies the specified month-end and leap-year
/// behavior when a target month does not contain the original day.
List<Subscription> autoAdvanceDueDates(
  List<Subscription> subscriptions, {
  required DateTime today,
}) {
  final todayDate = DateTime(today.year, today.month, today.day);

  return [
    for (final subscription in subscriptions)
      _advanceSubscription(subscription, todayDate),
  ];
}

Subscription _advanceSubscription(Subscription subscription, DateTime today) {
  var nextDueDate = subscription.nextDueDate;
  while (nextDueDate.isBefore(today)) {
    nextDueDate = switch (subscription.billingCycle) {
      BillingCycle.monthly => DateTime(
        nextDueDate.year,
        nextDueDate.month + 1,
        nextDueDate.day,
      ),
      BillingCycle.yearly => DateTime(
        nextDueDate.year + 1,
        nextDueDate.month,
        nextDueDate.day,
      ),
    };
  }
  return nextDueDate == subscription.nextDueDate
      ? subscription
      : subscription.copyWith(nextDueDate: nextDueDate);
}
