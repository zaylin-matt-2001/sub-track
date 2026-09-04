import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sub_track/core/constants/enums.dart';
import 'package:sub_track/features/subscriptions/domain/entities/subscription.dart';
import 'package:sub_track/features/subscriptions/domain/repositories/subscription_repository.dart';
import 'package:sub_track/features/subscriptions/presentation/controllers/providers.dart';
import 'package:sub_track/features/subscriptions/presentation/controllers/subscription_notifier.dart';
import 'package:sub_track/features/subscriptions/presentation/controllers/subscriptions_state.dart';

class FakeSubscriptionRepository implements SubscriptionRepository {
  final List<Subscription> _rows = <Subscription>[];
  int _nextId = 1;
  Object? throwOnNext;
  final List<String> callLog = <String>[];

  void seed(List<Subscription> subs) {
    for (final s in subs) {
      _rows.add(_withId(s, _nextId++));
    }
  }

  @override
  Future<List<Subscription>> getAll() async {
    callLog.add('getAll');
    _maybeThrow();
    return List.unmodifiable(_rows);
  }

  @override
  Future<Subscription> add(Subscription subscription) async {
    callLog.add('add');
    _maybeThrow();
    final saved = _withId(subscription, _nextId++);
    _rows.add(saved);
    return saved;
  }

  @override
  Future<void> update(Subscription subscription) async {
    callLog.add('update:${subscription.id}');
    _maybeThrow();
    final idx = _rows.indexWhere((s) => s.id == subscription.id);
    if (idx == -1) {
      throw StateError('No row with id ${subscription.id}');
    }
    _rows[idx] = subscription;
  }

  @override
  Future<void> delete(int id) async {
    callLog.add('delete:$id');
    _maybeThrow();
    _rows.removeWhere((s) => s.id == id);
  }

  void _maybeThrow() {
    final t = throwOnNext;
    throwOnNext = null;
    if (t != null) throw t;
  }

  Subscription _withId(Subscription s, int id) =>
      s.id == id ? s : s.copyWith(id: id);
}

Subscription _sub({
  required String name,
  required double cost,
  required BillingCycle cycle,
  required DateTime due,
  Category category = Category.streaming,
  int? id,
}) =>
    Subscription(
      id: id,
      name: name,
      cost: cost,
      billingCycle: cycle,
      nextDueDate: due,
      category: category,
    );

ProviderContainer _container(SubscriptionRepository repo) {
  return ProviderContainer(
    overrides: [
      subscriptionRepositoryProvider.overrideWithValue(repo),
    ],
  );
}

void main() {
  group('SubscriptionNotifier — initial load', () {
    test('build emits AsyncData with sorted list + computed totals',
        () async {
      final repo = FakeSubscriptionRepository();
      repo.seed([
        _sub(
            name: 'Spotify',
            cost: 9.99,
            cycle: BillingCycle.monthly,
            due: DateTime(2026, 9, 16)),
        _sub(
            name: 'iCloud',
            cost: 2.99,
            cycle: BillingCycle.monthly,
            due: DateTime(2026, 9, 15)),
      ]);
      final container = _container(repo);
      addTearDown(container.dispose);

      final initial = await container.read(subscriptionNotifierProvider.future);

      expect(initial.count, 2);
      expect(initial.subscriptions.first.name, 'iCloud');
      expect(initial.subscriptions.last.name, 'Spotify');
      expect(initial.monthlyBurnRate, closeTo(12.98, 1e-9));
      expect(initial.yearlyBurnRate, closeTo(155.76, 1e-9));
    });

    test('build on empty DB → AsyncData(empty state)', () async {
      final repo = FakeSubscriptionRepository();
      final container = _container(repo);
      addTearDown(container.dispose);

      final initial = await container.read(subscriptionNotifierProvider.future);

      expect(initial.subscriptions, isEmpty);
      expect(initial.count, 0);
      expect(initial.monthlyBurnRate, 0);
      expect(initial.yearlyBurnRate, 0);
      expect(initial, equals(SubscriptionsState.empty));
    });

    test('DB error during build → AsyncError', () async {
      final repo = FakeSubscriptionRepository()
        ..throwOnNext = StateError('db down');
      final container = _container(repo);
      addTearDown(container.dispose);

      await expectLater(
        container.read(subscriptionNotifierProvider.future),
        throwsA(isA<StateError>()),
      );
      final snap = container.read(subscriptionNotifierProvider);
      expect(snap.hasError, isTrue);
      expect(snap.error, isA<StateError>());
    });
  });

  group('SubscriptionNotifier — mutations emit exactly one AsyncData', () {
    late List<AsyncValue<SubscriptionsState>> emissions;
    late ProviderContainer container;
    late FakeSubscriptionRepository repo;

    setUp(() async {
      repo = FakeSubscriptionRepository();
      container = _container(repo);
      addTearDown(container.dispose);
      emissions = <AsyncValue<SubscriptionsState>>[];
      container.listen<AsyncValue<SubscriptionsState>>(
        subscriptionNotifierProvider,
        (_, next) => emissions.add(next),
      );
      await container.read(subscriptionNotifierProvider.future);
    });

    test('addSubscription → one AsyncData with recomputed totals', () async {
      final before = container.read(subscriptionNotifierProvider).requireValue;
      expect(before.count, 0);
      final emissionCountBefore = emissions.length;

      final notifier = container.read(subscriptionNotifierProvider.notifier);
      await notifier.addSubscription(_sub(
        name: 'Netflix',
        cost: 14.99,
        cycle: BillingCycle.monthly,
        due: DateTime(2026, 9, 20),
      ));

      final newEmissions =
          emissions.sublist(emissionCountBefore).toList();
      final dataEmissions =
          newEmissions.whereType<AsyncData<SubscriptionsState>>().toList();
      expect(dataEmissions, hasLength(1),
          reason: 'expected exactly one AsyncData emission per mutation');

      final after = dataEmissions.last.value;
      expect(after.count, 1);
      expect(after.subscriptions.first.name, 'Netflix');
      expect(after.monthlyBurnRate, closeTo(14.99, 1e-9));
      expect(after.yearlyBurnRate, closeTo(179.88, 1e-9));
    });

    test(
      'addSubscription with yearly cost uses cost/12 in the monthly total',
      () async {
        final notifier = container.read(subscriptionNotifierProvider.notifier);
        await notifier.addSubscription(_sub(
          name: 'Domain',
          cost: 120.0,
          cycle: BillingCycle.yearly,
          due: DateTime(2026, 9, 20),
        ));
        final after = container
            .read(subscriptionNotifierProvider)
            .requireValue;
        expect(after.monthlyBurnRate, closeTo(10.0, 1e-9));
        expect(after.yearlyBurnRate, closeTo(120.0, 1e-9));
        expect(after.count, 1);
      },
    );

    test('updateSubscription → one AsyncData with recomputed totals',
        () async {
      final notifier = container.read(subscriptionNotifierProvider.notifier);
      await notifier.addSubscription(_sub(
        name: 'Netflix',
        cost: 14.99,
        cycle: BillingCycle.monthly,
        due: DateTime(2026, 9, 20),
      ));

      final current =
          container.read(subscriptionNotifierProvider).requireValue;
      final existing = current.subscriptions.first;
      final emissionCountBefore = emissions.length;
      await notifier.updateSubscription(existing.copyWith(
        name: 'Netflix Premium',
        cost: 22.99,
      ));

      final newEmissions =
          emissions.sublist(emissionCountBefore).toList();
      final dataEmissions =
          newEmissions.whereType<AsyncData<SubscriptionsState>>().toList();
      expect(dataEmissions, hasLength(1));
      final after = dataEmissions.last.value;
      expect(after.count, 1);
      expect(after.subscriptions.first.name, 'Netflix Premium');
      expect(after.monthlyBurnRate, closeTo(22.99, 1e-9));
      expect(after.yearlyBurnRate, closeTo(275.88, 1e-9));
    });

    test('deleteSubscription → one AsyncData with recomputed totals',
        () async {
      final notifier = container.read(subscriptionNotifierProvider.notifier);
      await notifier.addSubscription(_sub(
        name: 'Netflix',
        cost: 14.99,
        cycle: BillingCycle.monthly,
        due: DateTime(2026, 9, 20),
      ));
      await notifier.addSubscription(_sub(
        name: 'Spotify',
        cost: 9.99,
        cycle: BillingCycle.monthly,
        due: DateTime(2026, 9, 21),
      ));

      final current =
          container.read(subscriptionNotifierProvider).requireValue;
      final netflix =
          current.subscriptions.firstWhere((s) => s.name == 'Netflix');
      final emissionCountBefore = emissions.length;
      await notifier.deleteSubscription(netflix.id!);

      final newEmissions =
          emissions.sublist(emissionCountBefore).toList();
      final dataEmissions =
          newEmissions.whereType<AsyncData<SubscriptionsState>>().toList();
      expect(dataEmissions, hasLength(1));
      final after = dataEmissions.last.value;
      expect(after.count, 1);
      expect(after.subscriptions.first.name, 'Spotify');
      expect(after.monthlyBurnRate, closeTo(9.99, 1e-9));
      expect(after.yearlyBurnRate, closeTo(119.88, 1e-9));
    });

    test('mutation after a DB error surfaces the error as AsyncError',
        () async {
      repo.throwOnNext = StateError('write failed');
      final notifier = container.read(subscriptionNotifierProvider.notifier);
      await expectLater(
        notifier.addSubscription(_sub(
          name: 'Netflix',
          cost: 14.99,
          cycle: BillingCycle.monthly,
          due: DateTime(2026, 9, 20),
        )),
        throwsA(isA<StateError>()),
      );
      final snap = container.read(subscriptionNotifierProvider);
      expect(snap.hasError, isTrue);
      expect(snap.error, isA<StateError>());
    });
  });
}
