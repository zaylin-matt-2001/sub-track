import '../entities/subscription.dart';
import '../repositories/subscription_repository.dart';

class AddSubscription {
  final SubscriptionRepository _repository;

  const AddSubscription(this._repository);

  Future<Subscription> call(Subscription subscription) {
    return _repository.add(subscription);
  }
}
