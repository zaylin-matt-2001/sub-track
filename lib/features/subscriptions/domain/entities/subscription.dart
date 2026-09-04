import '../../../../core/constants/enums.dart';

class Subscription {
  final int? id;
  final String name;
  final double cost;
  final BillingCycle billingCycle;
  final DateTime nextDueDate;
  final Category category;
  final String? iconName;

  const Subscription({
    this.id,
    required this.name,
    required this.cost,
    required this.billingCycle,
    required this.nextDueDate,
    required this.category,
    this.iconName,
  });

  Subscription copyWith({
    int? id,
    String? name,
    double? cost,
    BillingCycle? billingCycle,
    DateTime? nextDueDate,
    Category? category,
    String? iconName,
  }) {
    return Subscription(
      id: id ?? this.id,
      name: name ?? this.name,
      cost: cost ?? this.cost,
      billingCycle: billingCycle ?? this.billingCycle,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      category: category ?? this.category,
      iconName: iconName ?? this.iconName,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Subscription &&
        other.id == id &&
        other.name == name &&
        other.cost == cost &&
        other.billingCycle == billingCycle &&
        other.nextDueDate == nextDueDate &&
        other.category == category &&
        other.iconName == iconName;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        cost,
        billingCycle,
        nextDueDate,
        category,
        iconName,
      );
}
