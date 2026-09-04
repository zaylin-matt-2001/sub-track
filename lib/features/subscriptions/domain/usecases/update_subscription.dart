import '../entities/subscription.dart';
import '../repositories/subscription_repository.dart';

class UpdateSubscription {
  final SubscriptionRepository _repository;

  const UpdateSubscription(this._repository);

  Future<void> call(Subscription subscription) {
    return _repository.update(subscription);
  }
}
