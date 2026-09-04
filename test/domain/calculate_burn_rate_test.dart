import 'package:flutter_test/flutter_test.dart';
import 'package:sub_track/core/constants/enums.dart';
import 'package:sub_track/features/subscriptions/domain/entities/subscription.dart';
import 'package:sub_track/features/subscriptions/domain/usecases/calculate_burn_rate.dart';

Subscription _sub({
  required double cost,
  required BillingCycle cycle,
  String name = 'S',
  int? id,
  bool isActive = true,
  String currencyCode = 'USD',
}) {
  return Subscription(
    id: id,
    name: name,
    cost: cost,
    billingCycle: cycle,
    nextDueDate: DateTime(2026, 9, 15),
    category: Category.other,
    isActive: isActive,
    currencyCode: currencyCode,
  );
}

void main() {
  group('calculateBurnRate — empty', () {
    test('empty list → 0 / 0 / 0', () {
      final result = calculateBurnRate(const []);
      expect(result.monthly, 0);
      expect(result.yearly, 0);
      expect(result.count, 0);
    });

    test('matches BurnRate.empty', () {
      expect(calculateBurnRate(const []), BurnRate.empty);
    });
  });

  group('calculateBurnRate — monthly-only', () {
    test('single monthly subscription', () {
      final result = calculateBurnRate([
        _sub(cost: 9.99, cycle: BillingCycle.monthly),
      ]);
      expect(result.monthly, 9.99);
      expect(result.yearly, closeTo(119.88, 1e-9));
      expect(result.count, 1);
    });

    test('sums multiple monthly subscriptions', () {
      final result = calculateBurnRate([
        _sub(cost: 9.99, cycle: BillingCycle.monthly),
        _sub(cost: 14.99, cycle: BillingCycle.monthly),
        _sub(cost: 5.00, cycle: BillingCycle.monthly),
      ]);
      expect(result.monthly, 29.98);
      expect(result.yearly, closeTo(359.76, 1e-9));
      expect(result.count, 3);
    });
  });

  group('calculateBurnRate — yearly-only', () {
    test('single yearly subscription is divided by 12 in memory', () {
      final result = calculateBurnRate([
        _sub(cost: 120.00, cycle: BillingCycle.yearly),
      ]);
      expect(result.monthly, closeTo(10.00, 1e-9));
      expect(result.yearly, closeTo(120.00, 1e-9));
      expect(result.count, 1);
    });

    test('yearly cost / 12 keeps full double precision in the sum (no rounding drift)', () {
      final result = calculateBurnRate([
        _sub(cost: 100.00, cycle: BillingCycle.yearly),
      ]);
      expect(result.monthly, closeTo(8.3333333333333339, 1e-12));
      expect(result.yearly, closeTo(100.00, 1e-12));
    });

    test('sums multiple yearly subscriptions with /12 each', () {
      final result = calculateBurnRate([
        _sub(cost: 120.00, cycle: BillingCycle.yearly),
        _sub(cost: 60.00, cycle: BillingCycle.yearly),
      ]);
      expect(result.monthly, closeTo(15.00, 1e-9));
      expect(result.yearly, closeTo(180.00, 1e-9));
      expect(result.count, 2);
    });
  });

  group('calculateBurnRate — mixed', () {
    test('adds monthly as-is and yearly as cost/12', () {
      final result = calculateBurnRate([
        _sub(cost: 10.00, cycle: BillingCycle.monthly),
        _sub(cost: 120.00, cycle: BillingCycle.yearly),
      ]);
      expect(result.monthly, closeTo(20.00, 1e-9));
      expect(result.yearly, closeTo(240.00, 1e-9));
      expect(result.count, 2);
    });

    test('monthly × 12 equals yearly total exactly', () {
      final subs = [
        _sub(cost: 9.99, cycle: BillingCycle.monthly),
        _sub(cost: 14.99, cycle: BillingCycle.monthly),
        _sub(cost: 60.00, cycle: BillingCycle.yearly),
        _sub(cost: 120.00, cycle: BillingCycle.yearly),
      ];
      final result = calculateBurnRate(subs);
      expect(result.monthly * 12.0, closeTo(result.yearly, 1e-9));
      expect(result.count, 4);
    });
  });

  group('calculateBurnRate — purity', () {
    test('does not mutate the input list', () {
      final original = [
        _sub(cost: 10.00, cycle: BillingCycle.monthly),
        _sub(cost: 60.00, cycle: BillingCycle.yearly),
      ];
      final snapshot = List.of(original);
      calculateBurnRate(original);
      expect(original.length, snapshot.length);
      for (var i = 0; i < original.length; i++) {
        expect(original[i], snapshot[i]);
      }
    });
  });

  // ── M8: Active/Paused behaviour ──────────────────────────────────────────
  group('calculateBurnRate — paused subscriptions (M8)', () {
    test('all-paused list → 0 / 0 / count=0', () {
      final result = calculateBurnRate([
        _sub(cost: 9.99, cycle: BillingCycle.monthly, isActive: false),
        _sub(cost: 60.00, cycle: BillingCycle.yearly, isActive: false),
      ]);
      expect(result.monthly, 0);
      expect(result.yearly, 0);
      expect(result.count, 0);
    });

    test('paused subscription is excluded from monthly total', () {
      final result = calculateBurnRate([
        _sub(cost: 10.00, cycle: BillingCycle.monthly, isActive: true),
        _sub(cost: 5.00, cycle: BillingCycle.monthly, isActive: false),
      ]);
      expect(result.monthly, 10.00);
      expect(result.yearly, closeTo(120.00, 1e-9));
      expect(result.count, 1);
    });

    test('paused yearly subscription does not contribute to totals', () {
      final result = calculateBurnRate([
        _sub(cost: 10.00, cycle: BillingCycle.monthly, isActive: true),
        _sub(cost: 120.00, cycle: BillingCycle.yearly, isActive: false),
      ]);
      expect(result.monthly, 10.00);
      expect(result.count, 1);
    });

    test('count reflects only active subscriptions', () {
      final result = calculateBurnRate([
        _sub(cost: 1.00, cycle: BillingCycle.monthly, isActive: true),
        _sub(cost: 2.00, cycle: BillingCycle.monthly, isActive: true),
        _sub(cost: 3.00, cycle: BillingCycle.monthly, isActive: false),
      ]);
      expect(result.count, 2);
    });

    test(
      'single active subscription among many paused returns correct total',
      () {
        final result = calculateBurnRate([
          _sub(cost: 100.00, cycle: BillingCycle.monthly, isActive: false),
          _sub(cost: 200.00, cycle: BillingCycle.monthly, isActive: false),
          _sub(cost: 7.99, cycle: BillingCycle.monthly, isActive: true),
        ]);
        expect(result.monthly, 7.99);
        expect(result.count, 1);
      },
    );
  });

  group('calculateBurnRate — exchange rates (M9)', () {
    test(
      'converts monthly and yearly costs into the selected base currency',
      () {
        final result = calculateBurnRate(
          [
            _sub(cost: 10, cycle: BillingCycle.monthly, currencyCode: 'EUR'),
            _sub(cost: 120, cycle: BillingCycle.yearly, currencyCode: 'GBP'),
            _sub(cost: 5, cycle: BillingCycle.monthly, currencyCode: 'USD'),
          ],
          exchangeRates: const {'EUR': 1.10, 'GBP': 1.25},
          baseCurrency: 'USD',
        );

        expect(result.monthly, closeTo(28.5, 1e-9));
        expect(result.yearly, closeTo(342, 1e-9));
        expect(result.count, 3);
      },
    );

    test('uses 1.0 for a missing exchange rate', () {
      final result = calculateBurnRate(
        [_sub(cost: 12, cycle: BillingCycle.monthly, currencyCode: 'CAD')],
        exchangeRates: const {'EUR': 1.10},
        baseCurrency: 'USD',
      );

      expect(result.monthly, 12);
      expect(result.yearly, 144);
    });

    test('always treats the base currency as 1.0', () {
      final result = calculateBurnRate(
        [_sub(cost: 10, cycle: BillingCycle.monthly, currencyCode: 'EUR')],
        exchangeRates: const {'EUR': 99},
        baseCurrency: 'eur',
      );

      expect(result.monthly, 10);
    });
  });
}
