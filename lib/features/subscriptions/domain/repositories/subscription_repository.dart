import '../entities/subscription.dart';

abstract class SubscriptionRepository {
  Future<List<Subscription>> getAll();
  Future<Subscription> add(Subscription subscription);
  Future<void> update(Subscription subscription);
  Future<void> delete(int id);
}
