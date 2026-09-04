import 'package:flutter_test/flutter_test.dart';
import 'package:sub_track/core/constants/enums.dart';
import 'package:sub_track/features/subscriptions/domain/entities/subscription.dart';

Subscription _sample({int? id, String? name, double? cost}) => Subscription(
      id: id,
      name: name ?? 'Netflix',
      cost: cost ?? 14.99,
      billingCycle: BillingCycle.monthly,
      nextDueDate: DateTime(2026, 9, 15),
      category: Category.streaming,
      iconName: 'streaming',
    );

void main() {
  group('Subscription entity — contract', () {
    test('all fields exposed and immutable', () {
      final s = _sample(id: 1);
      expect(s.id, 1);
      expect(s.name, 'Netflix');
      expect(s.cost, 14.99);
      expect(s.billingCycle, BillingCycle.monthly);
      expect(s.nextDueDate, DateTime(2026, 9, 15));
      expect(s.category, Category.streaming);
      expect(s.iconName, 'streaming');
    });

    test('value equality across all fields', () {
      final a = _sample();
      final b = _sample();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('differs when any field differs', () {
      expect(_sample(), isNot(equals(_sample(name: 'Spotify'))));
      expect(_sample(), isNot(equals(_sample(cost: 9.99))));
    });

    test('copyWith returns a new instance with the patch applied', () {
      final base = _sample();
      final patched = base.copyWith(name: 'Spotify', iconName: 'music');
      expect(identical(base, patched), isFalse);
      expect(patched.name, 'Spotify');
      expect(patched.iconName, 'music');
      expect(patched.cost, base.cost);
      expect(patched.billingCycle, base.billingCycle);
    });
  });
}
