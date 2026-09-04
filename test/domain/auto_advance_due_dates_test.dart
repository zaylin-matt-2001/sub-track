import 'package:flutter_test/flutter_test.dart';
import 'package:sub_track/core/constants/enums.dart';
import 'package:sub_track/features/subscriptions/domain/entities/subscription.dart';
import 'package:sub_track/features/subscriptions/domain/usecases/auto_advance_due_dates.dart';

Subscription _subscription({
  required DateTime dueDate,
  required BillingCycle cycle,
}) {
  return Subscription(
    id: 1,
    name: 'Test subscription',
    cost: 10,
    billingCycle: cycle,
    nextDueDate: dueDate,
    category: Category.other,
  );
}

void main() {
  group('autoAdvanceDueDates', () {
    test('leaves a due date that is today unchanged', () {
      final subscription = _subscription(
        dueDate: DateTime(2026, 9, 4),
        cycle: BillingCycle.monthly,
      );

      final result = autoAdvanceDueDates([
        subscription,
      ], today: DateTime(2026, 9, 4, 23, 59));

      expect(result.single, same(subscription));
    });

    test('advances a past monthly due date across multiple cycles', () {
      final result = autoAdvanceDueDates([
        _subscription(
          dueDate: DateTime(2026, 1, 10),
          cycle: BillingCycle.monthly,
        ),
      ], today: DateTime(2026, 9, 1));

      expect(result.single.nextDueDate, DateTime(2026, 9, 10));
    });

    test('uses Dart DateTime month-end wrapping semantics', () {
      final result = autoAdvanceDueDates([
        _subscription(
          dueDate: DateTime(2026, 1, 31),
          cycle: BillingCycle.monthly,
        ),
      ], today: DateTime(2026, 6, 1));

      // DateTime(2026, 2, 31) wraps to 3 March; subsequent cycles land on
      // the third, so the first non-past occurrence is 3 June.
      expect(result.single.nextDueDate, DateTime(2026, 6, 3));
    });

    test('uses Dart DateTime leap-year semantics for yearly subscriptions', () {
      final result = autoAdvanceDueDates([
        _subscription(
          dueDate: DateTime(2024, 2, 29),
          cycle: BillingCycle.yearly,
        ),
      ], today: DateTime(2025, 3, 1));

      // DateTime(2025, 2, 29) normalizes to 1 March 2025.
      expect(result.single.nextDueDate, DateTime(2025, 3, 1));
    });
  });
}
