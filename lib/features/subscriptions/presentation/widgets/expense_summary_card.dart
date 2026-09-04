import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../controllers/subscriptions_state.dart';

class ExpenseSummaryCard extends StatelessWidget {
  final SubscriptionsState state;

  const ExpenseSummaryCard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Monthly burn rate',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatCurrency(state.monthlyBurnRate),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: 'Yearly',
                    value: formatCurrency(state.yearlyBurnRate),
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: 'Subscriptions',
                    value: '${state.count}',
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

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        )),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.titleLarge),
      ],
    );
  }
}
