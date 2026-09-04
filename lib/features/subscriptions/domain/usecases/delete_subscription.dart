import '../repositories/subscription_repository.dart';

class DeleteSubscription {
  final SubscriptionRepository _repository;

  const DeleteSubscription(this._repository);

  Future<void> call(int id) {
    return _repository.delete(id);
  }
}
