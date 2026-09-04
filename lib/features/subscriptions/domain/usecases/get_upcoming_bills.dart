import '../entities/subscription.dart';

List<Subscription> getUpcomingBills(List<Subscription> subscriptions) {
  final copy = List<Subscription>.of(subscriptions);
  copy.sort((a, b) {
    final byDate = a.nextDueDate.compareTo(b.nextDueDate);
    if (byDate != 0) return byDate;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return copy;
}
