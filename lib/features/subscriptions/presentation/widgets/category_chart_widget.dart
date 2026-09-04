import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/usecases/get_category_breakdown.dart';

/// Pie chart of active subscriptions grouped by [Category].
///
/// Slices are colored from the M3 [ColorScheme] and an inline legend lists
/// each category with its share of the active monthly burn rate (formatted in
/// the dashboard's base currency).
class CategoryChartWidget extends StatelessWidget {
  final List<CategoryBreakdownEntry> entries;
  final String baseCurrency;

  const CategoryChartWidget({
    super.key,
    required this.entries,
    this.baseCurrency = 'USD',
  });

  static const _categoryOrder = Category.values;

  Color _colorFor(BuildContext context, Category category) {
    final scheme = Theme.of(context).colorScheme;
    switch (category) {
      case Category.streaming:
        return scheme.primary;
      case Category.software:
        return scheme.secondary;
      case Category.fitness:
        return scheme.tertiary;
      case Category.utilities:
        return scheme.primaryContainer;
      case Category.other:
        return scheme.secondaryContainer;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (entries.isEmpty) {
      return Card(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.pie_chart_outline,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No active subscriptions to chart yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final total = entries.fold<double>(0, (sum, e) => sum + e.amount);
    final sections = <PieChartSectionData>[];
    final usedCategories = <Category>{for (final e in entries) e.category};

    for (final category in _categoryOrder) {
      if (!usedCategories.contains(category)) continue;
      final entry = entries.firstWhere((e) => e.category == category);
      final color = _colorFor(context, category);
      final percent = total == 0 ? 0 : (entry.amount / total) * 100;
      sections.add(
        PieChartSectionData(
          value: entry.amount,
          color: color,
          title: percent >= 8 ? '${percent.toStringAsFixed(0)}%' : '',
          radius: 64,
          titleStyle: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.w600,
          ),
          titlePositionPercentageOffset: 0.6,
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.pie_chart_outline,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Spending by category',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  height: 160,
                  width: 160,
                  child: PieChart(
                    PieChartData(
                      sections: sections,
                      centerSpaceRadius: 32,
                      sectionsSpace: 2,
                      startDegreeOffset: -90,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final entry in entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: _LegendRow(
                            color: _colorFor(context, entry.category),
                            label: entry.category.storageId,
                            value: formatCurrency(
                              entry.amount,
                              currencyCode: baseCurrency,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 90),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
