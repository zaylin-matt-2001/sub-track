import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sub_track/app/theme/app_theme.dart';
import 'package:sub_track/core/constants/enums.dart';
import 'package:sub_track/features/subscriptions/domain/entities/subscription.dart';
import 'package:sub_track/features/subscriptions/domain/repositories/subscription_repository.dart';
import 'package:sub_track/features/subscriptions/presentation/controllers/providers.dart';
import 'package:sub_track/features/subscriptions/presentation/screens/dashboard_screen.dart';
import 'package:sub_track/features/subscriptions/presentation/widgets/subscription_tile.dart';

class _StaticRepo implements SubscriptionRepository {
  final List<Subscription> rows;
  _StaticRepo(this.rows);

  @override
  Future<List<Subscription>> getAll() async => List.unmodifiable(rows);

  @override
  Future<Subscription> add(Subscription s) async => s;

  @override
  Future<void> update(Subscription s) async {}

  @override
  Future<void> updateAll(Iterable<Subscription> subscriptions) async {}

  @override
  Future<void> delete(int id) async {}
}

Subscription _huge() => Subscription(
  id: 1,
  name: 'Very-Long Subscription Name That Should Ellipsize',
  cost: 1234567890.12,
  billingCycle: BillingCycle.monthly,
  nextDueDate: DateTime(2026, 9, 20),
  category: Category.streaming,
  iconName: 'streaming',
);

Future<void> _pumpNarrow(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(360, 720);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        subscriptionRepositoryProvider.overrideWithValue(
          _StaticRepo([_huge()]),
        ),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('very-large cost renders without overflow on a narrow viewport', (
    tester,
  ) async {
    await _pumpNarrow(tester, const DashboardScreen());

    // No exception during layout is the primary assertion. Verify the cost
    // text was rendered (FittedBox will scale it down to fit).
    expect(find.textContaining(r'$'), findsWidgets);

    // Explicit Flutter overflow warning check: ensure no widgets logged
    // "RenderFlex overflowed". Flutter test harness records these; if a
    // RenderFlex in our tree had overflowed, pumpAndSettle would have thrown.
  });

  testWidgets('long name in SubscriptionTile does not overflow', (
    tester,
  ) async {
    final tile = SubscriptionTile(
      subscription: _huge(),
      onConfirmDelete: () async => false,
    );
    await _pumpNarrow(tester, Scaffold(body: ListView(children: [tile])));

    expect(find.textContaining('Very-Long'), findsOneWidget);
  });
}
