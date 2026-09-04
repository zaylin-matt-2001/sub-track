import '../../../../core/constants/enums.dart';
import '../entities/subscription.dart';

/// A single slice in the category breakdown chart.
class CategoryBreakdownEntry {
  final Category category;
  final double amount;

  const CategoryBreakdownEntry({required this.category, required this.amount});
}

/// Returns the sum of active base-currency monthly costs, grouped by
/// [Category].
///
/// The grouping is pure and mirrors the conversion math used by
/// [calculateBurnRate] so a chart slice's share always sums to the dashboard's
/// active monthly burn rate. Paused subscriptions are ignored, and categories
/// with no active subscriptions are omitted from the returned map.
Map<Category, double> getCategoryBreakdown(
  List<Subscription> subscriptions, {
  Map<String, double> exchangeRates = const <String, double>{},
  String baseCurrency = 'USD',
}) {
  final result = <Category, double>{};
  for (final s in subscriptions) {
    if (!s.isActive) continue;
    final rate = s.currencyCode.toUpperCase() == baseCurrency.toUpperCase()
        ? 1.0
        : exchangeRates[s.currencyCode.toUpperCase()] ?? 1.0;
    final monthly = switch (s.billingCycle) {
      BillingCycle.monthly => s.cost,
      BillingCycle.yearly => s.cost / 12.0,
    };
    final amount = monthly * rate;
    result[s.category] = (result[s.category] ?? 0) + amount;
  }
  return result;
}

/// Convenience wrapper that returns the breakdown as an ordered list of
/// [CategoryBreakdownEntry] sorted by amount descending. Ties keep the natural
/// [Category] enum order so the chart slices stay stable between rebuilds.
List<CategoryBreakdownEntry> getCategoryBreakdownList(
  List<Subscription> subscriptions, {
  Map<String, double> exchangeRates = const <String, double>{},
  String baseCurrency = 'USD',
}) {
  final map = getCategoryBreakdown(
    subscriptions,
    exchangeRates: exchangeRates,
    baseCurrency: baseCurrency,
  );
  final entries = [
    for (final entry in map.entries)
      CategoryBreakdownEntry(category: entry.key, amount: entry.value),
  ];
  entries.sort((a, b) {
    final byAmount = b.amount.compareTo(a.amount);
    if (byAmount != 0) return byAmount;
    return a.category.index.compareTo(b.category.index);
  });
  return entries;
}
