import 'package:flutter_test/flutter_test.dart';
import 'package:sub_track/core/constants/enums.dart';
import 'package:sub_track/features/subscriptions/domain/entities/subscription.dart';
import 'package:sub_track/features/subscriptions/domain/usecases/get_category_breakdown.dart';

Subscription _sub({
  required String name,
  required double cost,
  required BillingCycle cycle,
  required Category category,
  bool isActive = true,
  String currencyCode = 'USD',
}) {
  return Subscription(
    name: name,
    cost: cost,
    billingCycle: cycle,
    nextDueDate: DateTime(2026, 9, 15),
    category: category,
    isActive: isActive,
    currencyCode: currencyCode,
  );
}

void main() {
  group('getCategoryBreakdown — empty', () {
    test('empty list → empty map', () {
      final result = getCategoryBreakdown(const []);
      expect(result, isEmpty);
    });

    test('all-paused list → empty map', () {
      final result = getCategoryBreakdown([
        _sub(
          name: 'Spotify',
          cost: 9.99,
          cycle: BillingCycle.monthly,
          category: Category.streaming,
          isActive: false,
        ),
        _sub(
          name: 'iCloud',
          cost: 2.99,
          cycle: BillingCycle.monthly,
          category: Category.software,
          isActive: false,
        ),
      ]);
      expect(result, isEmpty);
    });
  });

  group('getCategoryBreakdown — grouping', () {
    test('sums monthly costs within a single category', () {
      final result = getCategoryBreakdown([
        _sub(
          name: 'Spotify',
          cost: 9.99,
          cycle: BillingCycle.monthly,
          category: Category.streaming,
        ),
        _sub(
          name: 'Netflix',
          cost: 14.99,
          cycle: BillingCycle.monthly,
          category: Category.streaming,
        ),
      ]);

      expect(result.length, 1);
      expect(result[Category.streaming], closeTo(24.98, 1e-9));
    });

    test('produces one entry per distinct active category', () {
      final result = getCategoryBreakdown([
        _sub(
          name: 'Spotify',
          cost: 9.99,
          cycle: BillingCycle.monthly,
          category: Category.streaming,
        ),
        _sub(
          name: 'iCloud',
          cost: 2.99,
          cycle: BillingCycle.monthly,
          category: Category.software,
        ),
        _sub(
          name: 'Gym',
          cost: 30,
          cycle: BillingCycle.monthly,
          category: Category.fitness,
        ),
      ]);

      expect(result.length, 3);
      expect(result[Category.streaming], 9.99);
      expect(result[Category.software], 2.99);
      expect(result[Category.fitness], 30);
    });

    test('omits categories that only contain paused subscriptions', () {
      final result = getCategoryBreakdown([
        _sub(
          name: 'Spotify',
          cost: 9.99,
          cycle: BillingCycle.monthly,
          category: Category.streaming,
        ),
        _sub(
          name: 'Disney+',
          cost: 7.99,
          cycle: BillingCycle.monthly,
          category: Category.streaming,
          isActive: false,
        ),
      ]);

      expect(result.length, 1);
      expect(result.containsKey(Category.streaming), isTrue);
      expect(result[Category.streaming], 9.99);
    });

    test('normalizes yearly costs to monthly (cost / 12)', () {
      final result = getCategoryBreakdown([
        _sub(
          name: 'Domain',
          cost: 120,
          cycle: BillingCycle.yearly,
          category: Category.software,
        ),
      ]);

      expect(result[Category.software], closeTo(10.0, 1e-9));
    });

    test(
      'breakdown sum equals the active monthly burn rate from '
      'calculateBurnRate',
      () {
        final subs = [
          _sub(
            name: 'Spotify',
            cost: 9.99,
            cycle: BillingCycle.monthly,
            category: Category.streaming,
          ),
          _sub(
            name: 'iCloud',
            cost: 2.99,
            cycle: BillingCycle.monthly,
            category: Category.software,
          ),
          _sub(
            name: 'Domain',
            cost: 120,
            cycle: BillingCycle.yearly,
            category: Category.software,
          ),
          _sub(
            name: 'Old Gym',
            cost: 30,
            cycle: BillingCycle.monthly,
            category: Category.fitness,
            isActive: false,
          ),
        ];

        final breakdown = getCategoryBreakdown(subs);
        final total = breakdown.values.fold<double>(0, (sum, v) => sum + v);

        expect(total, closeTo(9.99 + 2.99 + 10.0, 1e-9));
        expect(breakdown[Category.fitness], isNull);
      },
    );
  });

  group('getCategoryBreakdown — multi-currency', () {
    test('converts non-base currency subscriptions into the base currency', () {
      final result = getCategoryBreakdown(
        [
          _sub(
            name: 'Spotify EU',
            cost: 10,
            cycle: BillingCycle.monthly,
            category: Category.streaming,
            currencyCode: 'EUR',
          ),
          _sub(
            name: 'Local',
            cost: 5,
            cycle: BillingCycle.monthly,
            category: Category.streaming,
            currencyCode: 'USD',
          ),
        ],
        exchangeRates: const {'EUR': 1.10},
        baseCurrency: 'USD',
      );

      expect(result[Category.streaming], closeTo(16.0, 1e-9));
    });

    test('falls back to 1.0 when an exchange rate is missing', () {
      final result = getCategoryBreakdown(
        [
          _sub(
            name: 'Quora',
            cost: 12,
            cycle: BillingCycle.monthly,
            category: Category.software,
            currencyCode: 'CAD',
          ),
        ],
        exchangeRates: const {'EUR': 1.10},
        baseCurrency: 'USD',
      );

      expect(result[Category.software], 12);
    });
  });

  group('getCategoryBreakdownList — ordering', () {
    test('returns entries sorted by amount descending', () {
      final list = getCategoryBreakdownList([
        _sub(
          name: 'A',
          cost: 5,
          cycle: BillingCycle.monthly,
          category: Category.other,
        ),
        _sub(
          name: 'B',
          cost: 30,
          cycle: BillingCycle.monthly,
          category: Category.fitness,
        ),
        _sub(
          name: 'C',
          cost: 12,
          cycle: BillingCycle.monthly,
          category: Category.streaming,
        ),
      ]);

      expect(list.length, 3);
      expect(list[0].category, Category.fitness);
      expect(list[1].category, Category.streaming);
      expect(list[2].category, Category.other);
    });

    test('empty input returns an empty list', () {
      final list = getCategoryBreakdownList(const []);
      expect(list, isEmpty);
    });
  });

  group('getCategoryBreakdown — purity', () {
    test('does not mutate the input list', () {
      final subs = [
        _sub(
          name: 'A',
          cost: 5,
          cycle: BillingCycle.monthly,
          category: Category.other,
        ),
      ];
      final snapshot = List.of(subs);
      getCategoryBreakdown(subs);
      expect(subs.length, snapshot.length);
      for (var i = 0; i < subs.length; i++) {
        expect(subs[i], snapshot[i]);
      }
    });
  });
}
