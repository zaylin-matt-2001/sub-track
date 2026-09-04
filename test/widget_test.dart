import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sub_track/app/theme/app_theme.dart';
import 'package:sub_track/features/subscriptions/domain/repositories/subscription_repository.dart';
import 'package:sub_track/features/subscriptions/domain/entities/subscription.dart';
import 'package:sub_track/features/subscriptions/presentation/controllers/providers.dart';
import 'package:sub_track/features/subscriptions/presentation/screens/dashboard_screen.dart';

class _NoopRepo implements SubscriptionRepository {
  const _NoopRepo();

  @override
  Future<List<Subscription>> getAll() async => const <Subscription>[];

  @override
  Future<Subscription> add(Subscription s) async => s;

  @override
  Future<void> update(Subscription s) async {}

  @override
  Future<void> delete(int id) async {}
}

void main() {
  testWidgets('SubTrack scaffold renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subscriptionRepositoryProvider.overrideWithValue(const _NoopRepo()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const DashboardScreen(),
        ),
      ),
    );

    expect(find.text('SubTrack'), findsOneWidget);
  });
}
