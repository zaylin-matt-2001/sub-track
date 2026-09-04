import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/constants/subscription_icons.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/due_date_formatter.dart';
import '../../domain/entities/subscription.dart';

class SubscriptionTile extends StatelessWidget {
  final Subscription subscription;
  final VoidCallback? onTap;
  final Future<bool> Function() onConfirmDelete;

  const SubscriptionTile({
    super.key,
    required this.subscription,
    required this.onConfirmDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dueColors =
        theme.extension<DueDateColors>() ??
        DueDateColors(
          overdue: theme.colorScheme.error,
          warning: Colors.amber,
          normal: theme.colorScheme.onSurfaceVariant,
        );

    final today = DateTime.now();
    final label = dueDateLabel(subscription.nextDueDate, today);
    final color = switch (label.severity) {
      DueDateSeverity.error => dueColors.overdue,
      DueDateSeverity.warning => dueColors.warning,
      DueDateSeverity.normal => dueColors.normal,
    };

    final iconData = resolveIcon(
      iconName: subscription.iconName,
      category: subscription.category,
    );

    final cycleLabel = subscription.billingCycle == BillingCycle.monthly
        ? '/mo'
        : '/yr';

    return Dismissible(
      key: ValueKey('sub-${subscription.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await onConfirmDelete();
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: theme.colorScheme.errorContainer,
        child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
      ),
      child: Opacity(
        opacity: subscription.isActive ? 1.0 : 0.45,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            onTap: onTap,
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.secondaryContainer,
              foregroundColor: theme.colorScheme.onSecondaryContainer,
              child: Icon(iconData),
            ),
            title: Text(subscription.name, overflow: TextOverflow.ellipsis),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _CategoryTag(category: subscription.category),
                    if (!subscription.isActive) _PausedTag(),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  label.text,
                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatCurrency(subscription.cost),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
                Text(
                  cycleLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryTag extends StatelessWidget {
  final Category category;

  const _CategoryTag({required this.category});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        category.storageId,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _PausedTag extends StatelessWidget {
  // ignore: unused_element
  const _PausedTag();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Paused',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onTertiaryContainer,
        ),
      ),
    );
  }
}
