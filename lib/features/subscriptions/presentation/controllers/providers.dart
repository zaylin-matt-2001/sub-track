import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../subscriptions/data/datasources/subscription_local_data_source.dart';
import '../../../subscriptions/data/repositories/subscription_repository_impl.dart';
import '../../../subscriptions/domain/repositories/subscription_repository.dart';
import '../../../settings/data/datasources/settings_local_data_source.dart';

final appDatabaseProvider = Provider<Database>((ref) {
  throw UnimplementedError(
    'appDatabaseProvider must be overridden in ProviderScope at app startup.',
  );
});

final subscriptionLocalDataSourceProvider =
    Provider<SubscriptionLocalDataSource>((ref) {
      final db = ref.watch(appDatabaseProvider);
      return SubscriptionLocalDataSource(db);
    });

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final dataSource = ref.watch(subscriptionLocalDataSourceProvider);
  return SubscriptionRepositoryImpl(dataSource);
});

/// Composition root for the settings feature's raw SQLite data source.
final settingsLocalDataSourceProvider = Provider<SettingsLocalDataSource>((
  ref,
) {
  final db = ref.watch(appDatabaseProvider);
  return SettingsLocalDataSource(db);
});
