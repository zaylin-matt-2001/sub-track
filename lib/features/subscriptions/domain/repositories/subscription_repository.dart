import '../entities/subscription.dart';

abstract class SubscriptionRepository {
  Future<List<Subscription>> getAll();
  Future<Subscription> add(Subscription subscription);
  Future<void> update(Subscription subscription);

  /// Persists a group of existing subscriptions in one operation.
  Future<void> updateAll(Iterable<Subscription> subscriptions);

  Future<void> delete(int id);
}
