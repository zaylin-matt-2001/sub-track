import 'package:flutter_test/flutter_test.dart';
import 'package:sub_track/core/constants/enums.dart';

void main() {
  group('BillingCycle', () {
    test('storage ids are lowercase', () {
      expect(BillingCycle.monthly.storageId, 'monthly');
      expect(BillingCycle.yearly.storageId, 'yearly');
    });

    test('round-trips known values', () {
      expect(BillingCycle.fromStorage('monthly'), BillingCycle.monthly);
      expect(BillingCycle.fromStorage('yearly'), BillingCycle.yearly);
    });

    test('falls back to monthly on unknown or null', () {
      expect(BillingCycle.fromStorage('weekly'), BillingCycle.monthly);
      expect(BillingCycle.fromStorage(''), BillingCycle.monthly);
      expect(BillingCycle.fromStorage(null), BillingCycle.monthly);
    });
  });

  group('Category', () {
    test('storage ids are PascalCase per PRD §3.2', () {
      expect(Category.streaming.storageId, 'Streaming');
      expect(Category.software.storageId, 'Software');
      expect(Category.fitness.storageId, 'Fitness');
      expect(Category.utilities.storageId, 'Utilities');
      expect(Category.other.storageId, 'Other');
    });

    test('round-trips known values', () {
      expect(Category.fromStorage('Streaming'), Category.streaming);
      expect(Category.fromStorage('Software'), Category.software);
      expect(Category.fromStorage('Fitness'), Category.fitness);
      expect(Category.fromStorage('Utilities'), Category.utilities);
      expect(Category.fromStorage('Other'), Category.other);
    });

    test('falls back to other on unknown or null', () {
      expect(Category.fromStorage('Groceries'), Category.other);
      expect(Category.fromStorage('streaming'), Category.other);
      expect(Category.fromStorage(''), Category.other);
      expect(Category.fromStorage(null), Category.other);
    });
  });
}
