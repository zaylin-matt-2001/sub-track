import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sub_track/app/theme/app_theme.dart';
import 'package:sub_track/core/constants/enums.dart';
import 'package:sub_track/features/subscriptions/domain/entities/subscription.dart';
import 'package:sub_track/features/subscriptions/domain/repositories/subscription_repository.dart';
import 'package:sub_track/features/subscriptions/presentation/controllers/providers.dart';
import 'package:sub_track/features/subscriptions/presentation/screens/dashboard_screen.dart';

class _FakeRepo implements SubscriptionRepository {
  final List<Subscription> _rows = <Subscription>[];
  int _nextId = 1;

  _FakeRepo({required this.seed}) {
    for (final s in seed) {
      _rows.add(_withId(s, _nextId++));
    }
  }

  final List<Subscription> seed;

  Subscription _withId(Subscription s, int id) =>
      s.id == id ? s : s.copyWith(id: id);

  @override
  Future<List<Subscription>> getAll() async =>
      List.unmodifiable(_rows);

  @override
  Future<Subscription> add(Subscription s) async {
    final saved = _withId(s, _nextId++);
    _rows.add(saved);
    return saved;
  }

  @override
  Future<void> update(Subscription s) async {
    final idx = _rows.indexWhere((x) => x.id == s.id);
    if (idx != -1) _rows[idx] = s;
  }

  @override
  Future<void> delete(int id) async {
    _rows.removeWhere((s) => s.id == id);
  }
}

Subscription _sub({
  required String name,
  required double cost,
  required BillingCycle cycle,
  required DateTime due,
  Category category = Category.streaming,
}) =>
    Subscription(
      name: name,
      cost: cost,
      billingCycle: cycle,
      nextDueDate: due,
      category: category,
    );

Widget _harness(SubscriptionRepository repo) {
  return ProviderScope(
    overrides: [
      subscriptionRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const DashboardScreen(),
    ),
  );
}

void main() {
  group('DashboardScreen — empty state', () {
    testWidgets('renders the empty-state widget when there are no subscriptions',
        (tester) async {
      await tester.pumpWidget(_harness(_FakeRepo(seed: const [])));
      await tester.pumpAndSettle();

      expect(find.text('No subscriptions yet'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });
  });

  group('DashboardScreen — seeded list', () {
    testWidgets(
      'shows correct monthly/yearly totals and sorted ordering',
      (tester) async {
        final repo = _FakeRepo(seed: [
          _sub(
            name: 'Spotify',
            cost: 9.99,
            cycle: BillingCycle.monthly,
            due: DateTime(2026, 9, 20),
          ),
          _sub(
            name: 'iCloud',
            cost: 2.99,
            cycle: BillingCycle.monthly,
            due: DateTime(2026, 9, 16),
          ),
          _sub(
            name: 'Domain',
            cost: 120.0,
            cycle: BillingCycle.yearly,
            due: DateTime(2026, 10, 1),
            category: Category.software,
          ),
        ]);

        await tester.pumpWidget(_harness(repo));
        await tester.pumpAndSettle();

        expect(find.text(r'$22.98'), findsOneWidget,
            reason: 'monthly = 9.99 + 2.99 + 120/12 = 22.98');
        expect(find.text(r'$275.76'), findsOneWidget,
            reason: 'yearly = 22.98 × 12');
        expect(find.text('3'), findsOneWidget);

        // Cards are sorted ascending by nextDueDate — iCloud first, Spotify next.
        final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
        expect(tiles.length, 3);
        expect((tiles[0].title as Text).data, 'iCloud');
        expect((tiles[1].title as Text).data, 'Spotify');
        expect((tiles[2].title as Text).data, 'Domain');
      },
    );
  });

  group('DashboardScreen — swipe to delete', () {
    testWidgets('swipe shows the confirm dialog and Cancel does nothing',
        (tester) async {
      final repo = _FakeRepo(seed: [
        _sub(
          name: 'Netflix',
          cost: 14.99,
          cycle: BillingCycle.monthly,
          due: DateTime(2026, 9, 18),
        ),
      ]);

      await tester.pumpWidget(_harness(repo));
      await tester.pumpAndSettle();

      // Swipe the Netflix tile end-to-start.
      final tile = find.text('Netflix');
      await tester.drag(tile, const Offset(-600, 0));
      await tester.pumpAndSettle();

      expect(find.text('Delete "Netflix"?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Netflix'), findsOneWidget,
          reason: 'cancelled swipe must not delete');
    });
  });
}
