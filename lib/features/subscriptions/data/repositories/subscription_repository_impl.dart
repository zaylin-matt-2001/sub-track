import '../../domain/entities/subscription.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../datasources/subscription_local_data_source.dart';
import '../models/subscription_model.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  final SubscriptionLocalDataSource _localDataSource;

  const SubscriptionRepositoryImpl(this._localDataSource);

  @override
  Future<List<Subscription>> getAll() async {
    final models = await _localDataSource.getAll();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<Subscription> add(Subscription subscription) async {
    final inserted = await _localDataSource.insert(
      SubscriptionModel.fromEntity(subscription),
    );
    return inserted.toEntity();
  }

  @override
  Future<void> update(Subscription subscription) async {
    await _localDataSource.update(SubscriptionModel.fromEntity(subscription));
  }

  @override
  Future<void> delete(int id) async {
    await _localDataSource.delete(id);
  }
}
