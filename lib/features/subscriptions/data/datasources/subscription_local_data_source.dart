import 'package:sqflite/sqflite.dart';

import '../models/subscription_model.dart';

class SubscriptionLocalDataSource {
  final Database _db;

  SubscriptionLocalDataSource(this._db);

  static const String _table = 'subscriptions';

  Future<List<SubscriptionModel>> getAll() async {
    final rows = await _db.query(_table, orderBy: 'next_due_date ASC');
    return rows.map(SubscriptionModel.fromMap).toList();
  }

  Future<SubscriptionModel> insert(SubscriptionModel model) async {
    final map = model.toMap();
    final id = await _db.insert(_table, map);
    return SubscriptionModel(
      id: id,
      name: model.name,
      cost: model.cost,
      billingCycle: model.billingCycle,
      nextDueDate: model.nextDueDate,
      category: model.category,
      iconName: model.iconName,
      isActive: model.isActive,
      currencyCode: model.currencyCode,
    );
  }

  Future<void> update(SubscriptionModel model) async {
    if (model.id == null) {
      throw ArgumentError('Cannot update a SubscriptionModel without an id.');
    }
    final map = model.toMap()..['id'] = model.id;
    await _db.update(_table, map, where: 'id = ?', whereArgs: [model.id]);
  }

  Future<void> delete(int id) async {
    await _db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}
