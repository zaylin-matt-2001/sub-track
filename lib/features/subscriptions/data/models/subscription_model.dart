import 'package:intl/intl.dart';

import '../../../../core/constants/enums.dart';
import '../../domain/entities/subscription.dart';

class SubscriptionModel {
  final int? id;
  final String name;
  final double cost;
  final BillingCycle billingCycle;
  final DateTime nextDueDate;
  final Category category;
  final String? iconName;

  const SubscriptionModel({
    this.id,
    required this.name,
    required this.cost,
    required this.billingCycle,
    required this.nextDueDate,
    required this.category,
    this.iconName,
  });

  factory SubscriptionModel.fromMap(Map<String, Object?> map) {
    return SubscriptionModel(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      cost: (map['cost'] as num?)?.toDouble() ?? 0.0,
      billingCycle:
          BillingCycle.fromStorage(map['billing_cycle'] as String?),
      nextDueDate: _parseDate(map['next_due_date'] as String?),
      category: Category.fromStorage(map['category'] as String?),
      iconName: map['icon_name'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    final m = <String, Object?>{
      'name': name,
      'cost': cost,
      'billing_cycle': billingCycle.storageId,
      'next_due_date': _formatDate(nextDueDate),
      'category': category.storageId,
      'icon_name': iconName,
    };
    if (id != null) m['id'] = id;
    return m;
  }

  factory SubscriptionModel.fromEntity(Subscription entity) {
    return SubscriptionModel(
      id: entity.id,
      name: entity.name,
      cost: entity.cost,
      billingCycle: entity.billingCycle,
      nextDueDate: entity.nextDueDate,
      category: entity.category,
      iconName: entity.iconName,
    );
  }

  Subscription toEntity() {
    return Subscription(
      id: id,
      name: name,
      cost: cost,
      billingCycle: billingCycle,
      nextDueDate: nextDueDate,
      category: category,
      iconName: iconName,
    );
  }
}

String _formatDate(DateTime dt) {
  final local = dt.isUtc ? dt.toLocal() : dt;
  return DateFormat("yyyy-MM-ddTHH:mm:ss.SSS").format(local);
}

DateTime _parseDate(String? raw) {
  if (raw == null || raw.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
  try {
    return DateTime.parse(raw);
  } catch (_) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
