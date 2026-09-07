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
          title: percent >= 12 ? '${percent.toStringAsFixed(0)}%' : '',
          radius: 48,
          titleStyle: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.w700,
          ),
          titlePositionPercentageOffset: 0.55,
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 420;
            final centerTotal = _formatCompactCurrency(
              total,
              currencyCode: baseCurrency,
            );
            final chart = SizedBox.square(
              dimension: compact ? 180 : 192,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sections: sections,
                      centerSpaceRadius: compact ? 40 : 44,
                      sectionsSpace: entries.length == 1 ? 0 : 3,
                      startDegreeOffset: -90,
                    ),
                    duration: const Duration(milliseconds: 250),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Monthly',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            centerTotal,
                            maxLines: 1,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
            final legend = Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.45,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
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
            );

            return Column(
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
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (compact) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(child: chart),
                  ),
                  const SizedBox(height: 12),
                  legend,
                ] else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        chart,
                        const SizedBox(width: 20),
                        Expanded(child: legend),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _formatCompactCurrency(num value, {required String currencyCode}) {
  final code = currencyCode.toUpperCase();
  final prefix = code == 'USD' ? r'$' : '$code ';
  final abs = value.abs();
  final sign = value < 0 ? '-' : '';

  if (abs >= 1000000) {
    return '$sign$prefix${_trimCompact(abs / 1000000)}M';
  }
  if (abs >= 1000) {
    return '$sign$prefix${_trimCompact(abs / 1000)}K';
  }
  return '$sign$prefix${abs.round()}';
}

String _trimCompact(double value) {
  final fixed = value >= 10
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
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
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
