import 'package:flutter_test/flutter_test.dart';
import 'package:sub_track/core/constants/enums.dart';
import 'package:sub_track/features/subscriptions/domain/entities/subscription.dart';
import 'package:sub_track/features/subscriptions/domain/usecases/get_upcoming_bills.dart';

Subscription _sub({
  required String name,
  required DateTime due,
  double cost = 9.99,
}) {
  return Subscription(
    name: name,
    cost: cost,
    billingCycle: BillingCycle.monthly,
    nextDueDate: due,
    category: Category.other,
  );
}

void main() {
  group('getUpcomingBills — sort', () {
    test('orders ascending by nextDueDate', () {
      final result = getUpcomingBills([
        _sub(name: 'Late', due: DateTime(2026, 10, 1)),
        _sub(name: 'Soon', due: DateTime(2026, 9, 16)),
        _sub(name: 'Medium', due: DateTime(2026, 9, 20)),
      ]);
      expect(result.map((s) => s.name).toList(), ['Soon', 'Medium', 'Late']);
    });

    test('does not mutate the input list', () {
      final original = [
        _sub(name: 'Late', due: DateTime(2026, 10, 1)),
        _sub(name: 'Soon', due: DateTime(2026, 9, 16)),
      ];
      final snapshotNames = original.map((s) => s.name).toList();
      getUpcomingBills(original);
      expect(original.map((s) => s.name).toList(), snapshotNames);
    });
  });

  group('getUpcomingBills — name tie-break', () {
    test('same date → ascending by name (A→Z)', () {
      final shared = DateTime(2026, 9, 16);
      final result = getUpcomingBills([
        _sub(name: 'Charlie', due: shared),
        _sub(name: 'alpha', due: shared),
        _sub(name: 'Bravo', due: shared),
      ]);
      expect(result.map((s) => s.name).toList(), ['alpha', 'Bravo', 'Charlie']);
    });

    test('name comparison is case-insensitive', () {
      final shared = DateTime(2026, 9, 16);
      final result = getUpcomingBills([
        _sub(name: 'Zeta', due: shared),
        _sub(name: 'apple', due: shared),
      ]);
      expect(result.map((s) => s.name).toList(), ['apple', 'Zeta']);
    });

    test('date differences take priority over name', () {
      final result = getUpcomingBills([
        _sub(name: 'Zeta', due: DateTime(2026, 9, 20)),
        _sub(name: 'Apple', due: DateTime(2026, 9, 16)),
      ]);
      expect(result.map((s) => s.name).toList(), ['Apple', 'Zeta']);
    });
  });
}
