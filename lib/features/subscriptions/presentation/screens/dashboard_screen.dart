import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/subscription_notifier.dart';
import '../widgets/add_edit_subscription_sheet.dart';
import '../widgets/dashboard_empty_state.dart';
import '../widgets/expense_summary_card.dart';
import '../widgets/subscription_tile.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(subscriptionNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('SubTrack')),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            AddEditSubscriptionSheet.show(context),
        tooltip: 'Add subscription',
        child: const Icon(Icons.add),
      ),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Failed to load subscriptions: $e',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (state) {
          if (state.subscriptions.isEmpty) {
            return Column(
              children: [
                ExpenseSummaryCard(state: state),
                const Expanded(child: DashboardEmptyState()),
              ],
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              await ref
                  .read(subscriptionNotifierProvider.notifier)
                  .refresh();
            },
            child: ListView(
              children: [
                ExpenseSummaryCard(state: state),
                for (final sub in state.subscriptions)
                  SubscriptionTile(
                    subscription: sub,
                    onTap: () => AddEditSubscriptionSheet.show(
                      context,
                      existing: sub,
                    ),
                    onConfirmDelete: () async {
                      final ok = await _confirmDelete(context, sub.name);
                      if (!ok) return false;
                      await ref
                          .read(subscriptionNotifierProvider.notifier)
                          .deleteSubscription(sub.id!);
                      return true;
                    },
                  ),
                const SizedBox(height: 96),
              ],
            ),
          );
        },
      ),
    );
  }
}

Future<bool> _confirmDelete(BuildContext context, String name) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Delete "$name"?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return result ?? false;
}
