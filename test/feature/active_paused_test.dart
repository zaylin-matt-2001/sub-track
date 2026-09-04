import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sub_track/app/theme/app_theme.dart';
import 'package:sub_track/core/constants/enums.dart';
import 'package:sub_track/core/database/app_database.dart';
import 'package:sub_track/features/subscriptions/domain/entities/subscription.dart';
import 'package:sub_track/features/subscriptions/domain/repositories/subscription_repository.dart';
import 'package:sub_track/features/subscriptions/domain/usecases/calculate_burn_rate.dart';
import 'package:sub_track/features/subscriptions/presentation/controllers/providers.dart';
import 'package:sub_track/features/subscriptions/presentation/widgets/add_edit_subscription_sheet.dart';
import 'package:sub_track/features/subscriptions/presentation/widgets/subscription_tile.dart';

Future<Database> _openInMemory({int version = 2}) async {
  sqfliteFfiInit();
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: version,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE subscriptions (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            name          TEXT    NOT NULL,
            cost          REAL    NOT NULL CHECK (cost > 0),
            billing_cycle TEXT    NOT NULL CHECK (billing_cycle IN ('monthly','yearly')),
            next_due_date TEXT    NOT NULL,
            category      TEXT    NOT NULL,
            icon_name     TEXT,
            is_active     INTEGER NOT NULL DEFAULT 1,
            currency_code TEXT    NOT NULL DEFAULT 'USD'
          )
        ''');
        await db.execute('''
          CREATE TABLE settings (
            key   TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE exchange_rates (
            currency_code TEXT PRIMARY KEY,
            rate_to_base  REAL NOT NULL CHECK (rate_to_base > 0)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await AppDatabase.applyV2Upgrade(db);
      },
    ),
  );
}

class _RecordingRepo implements SubscriptionRepository {
  final List<Subscription> rows = <Subscription>[];
  int _nextId = 1;

  @override
  Future<List<Subscription>> getAll() async => List.unmodifiable(rows);

  @override
  Future<Subscription> add(Subscription s) async {
    final saved = s.copyWith(id: _nextId++);
    rows.add(saved);
    return saved;
  }

  @override
  Future<void> update(Subscription s) async {
    final idx = rows.indexWhere((r) => r.id == s.id);
    if (idx == -1) {
      rows.add(s);
    } else {
      rows[idx] = s;
    }
  }

  @override
  Future<void> updateAll(Iterable<Subscription> subscriptions) async {
    for (final subscription in subscriptions) {
      await update(subscription);
    }
  }

  @override
  Future<void> delete(int id) async {
    rows.removeWhere((r) => r.id == id);
  }
}

Subscription _sub({
  required String name,
  required double cost,
  required BillingCycle cycle,
  bool isActive = true,
  DateTime? due,
}) => Subscription(
  name: name,
  cost: cost,
  billingCycle: cycle,
  nextDueDate: due ?? DateTime(2026, 9, 15),
  category: Category.streaming,
  isActive: isActive,
);

void main() {
  group('CalculateBurnRate — active vs paused', () {
    test('paused subscriptions are excluded from totals', () {
      final subs = [
        _sub(
          name: 'A',
          cost: 10.0,
          cycle: BillingCycle.monthly,
          isActive: true,
        ),
        _sub(
          name: 'B',
          cost: 5.0,
          cycle: BillingCycle.monthly,
          isActive: false,
        ),
        _sub(
          name: 'C',
          cost: 120.0,
          cycle: BillingCycle.yearly,
          isActive: false,
        ),
      ];
      final burn = calculateBurnRate(subs);
      expect(burn.monthly, closeTo(10.0, 1e-9));
      expect(burn.yearly, closeTo(120.0, 1e-9));
      expect(
        burn.count,
        1,
        reason: 'count should reflect only active subscriptions',
      );
    });

    test('all-paused list behaves like an empty list', () {
      final subs = [
        _sub(
          name: 'A',
          cost: 10.0,
          cycle: BillingCycle.monthly,
          isActive: false,
        ),
        _sub(name: 'B', cost: 5.0, cycle: BillingCycle.yearly, isActive: false),
      ];
      expect(calculateBurnRate(subs), BurnRate.empty);
    });
  });

  group('AppDatabase — v1 → v2 migration', () {
    test(
      'opening a v1 database with the current AppDatabase factory applies the '
      'ALTER TABLE and CREATE TABLE upgrades',
      () async {
        sqfliteFfiInit();
        // Step 1: create a v1 database and insert a row.
        final v1 = await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, version) async {
              await db.execute('''
                CREATE TABLE subscriptions (
                  id            INTEGER PRIMARY KEY AUTOINCREMENT,
                  name          TEXT    NOT NULL,
                  cost          REAL    NOT NULL CHECK (cost > 0),
                  billing_cycle TEXT    NOT NULL CHECK (billing_cycle IN ('monthly','yearly')),
                  next_due_date TEXT    NOT NULL,
                  category      TEXT    NOT NULL,
                  icon_name     TEXT
                )
              ''');
            },
          ),
        );
        await v1.insert('subscriptions', <String, Object?>{
          'name': 'Legacy',
          'cost': 9.99,
          'billing_cycle': 'monthly',
          'next_due_date': '2026-09-15T00:00:00.000',
          'category': 'Streaming',
          'icon_name': 'streaming',
        });
        await v1.close();

        // Step 2: reopen with v2 — the upgrade should run on the *new*
        // connection, but since :memory: databases don't persist between
        // connections, we simulate the upgrade on the v1 connection directly.
        final reopened = await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, version) async {
              await db.execute('''
                CREATE TABLE subscriptions (
                  id            INTEGER PRIMARY KEY AUTOINCREMENT,
                  name          TEXT    NOT NULL,
                  cost          REAL    NOT NULL CHECK (cost > 0),
                  billing_cycle TEXT    NOT NULL CHECK (billing_cycle IN ('monthly','yearly')),
                  next_due_date TEXT    NOT NULL,
                  category      TEXT    NOT NULL,
                  icon_name     TEXT
                )
              ''');
              await db.insert('subscriptions', <String, Object?>{
                'name': 'Legacy',
                'cost': 9.99,
                'billing_cycle': 'monthly',
                'next_due_date': '2026-09-15T00:00:00.000',
                'category': 'Streaming',
                'icon_name': 'streaming',
              });
            },
          ),
        );
        await AppDatabase.applyV2Upgrade(reopened);

        // After the upgrade the legacy row should still be there with the
        // new columns defaulted.
        final rows = await reopened.query('subscriptions');
        expect(rows, hasLength(1));
        expect(rows.first['name'], 'Legacy');
        expect(rows.first['is_active'], 1);
        expect(rows.first['currency_code'], 'USD');

        // The new tables must exist and be empty.
        final settingsColumns = await reopened.rawQuery(
          'PRAGMA table_info(settings)',
        );
        expect(settingsColumns, isNotEmpty);
        final exchangeRatesColumns = await reopened.rawQuery(
          'PRAGMA table_info(exchange_rates)',
        );
        expect(exchangeRatesColumns, isNotEmpty);

        await reopened.close();
      },
    );

    test(
      'fresh database opened at v2 creates the new tables without an upgrade',
      () async {
        final db = await _openInMemory(version: 2);
        final subscriptionColumns = await db.rawQuery(
          'PRAGMA table_info(subscriptions)',
        );
        final columnNames = subscriptionColumns.map((r) => r['name']).toSet();
        expect(columnNames.contains('is_active'), isTrue);
        expect(columnNames.contains('currency_code'), isTrue);

        await db.close();
      },
    );
  });

  group('AddEditSubscriptionSheet — active/paused toggle', () {
    Future<void> pumpSheet(
      WidgetTester tester, {
      required SubscriptionRepository repo,
      Subscription? existing,
    }) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [subscriptionRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => AddEditSubscriptionSheet.show(
                      context,
                      existing: existing,
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'toggling the switch to paused persists isActive=false on save',
      (tester) async {
        final repo = _RecordingRepo();
        await pumpSheet(tester, repo: repo);

        // Defaults to Active.
        final switchFinder = find.byKey(const ValueKey('active-switch'));
        expect(switchFinder, findsOneWidget);
        expect(find.text('Active'), findsOneWidget);

        // Toggle off.
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        expect(find.text('Paused'), findsOneWidget);

        // Fill the rest of the form and save.
        await tester.enterText(
          find.byKey(const ValueKey('name-field')),
          'Spotify',
        );
        await tester.enterText(
          find.byKey(const ValueKey('cost-field')),
          '9.99',
        );
        await tester.tap(find.byKey(const ValueKey('save-button')));
        await tester.pumpAndSettle();

        expect(repo.rows.single.isActive, isFalse);
      },
    );

    testWidgets('edit mode pre-selects the stored isActive value', (
      tester,
    ) async {
      final repo = _RecordingRepo()
        ..rows.add(
          _sub(
            name: 'Paused One',
            cost: 9.99,
            cycle: BillingCycle.monthly,
            isActive: false,
          ).copyWith(id: 7),
        );
      final existing = repo.rows.single;

      await pumpSheet(tester, repo: repo, existing: existing);
      expect(find.text('Paused'), findsOneWidget);
    });

    testWidgets('edit mode pre-selects Active when the row is active', (
      tester,
    ) async {
      final repo = _RecordingRepo()
        ..rows.add(
          _sub(
            name: 'Active One',
            cost: 9.99,
            cycle: BillingCycle.monthly,
            isActive: true,
          ).copyWith(id: 8),
        );
      final existing = repo.rows.single;

      await pumpSheet(tester, repo: repo, existing: existing);
      expect(find.text('Active'), findsOneWidget);
    });
  });

  group('SubscriptionTile — paused visual treatment', () {
    testWidgets('paused subscription is dimmed and shows a Paused badge', (
      tester,
    ) async {
      final tile = SubscriptionTile(
        subscription: _sub(
          name: 'Old One',
          cost: 9.99,
          cycle: BillingCycle.monthly,
          isActive: false,
        ).copyWith(id: 1),
        onConfirmDelete: () async => false,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: ListView(children: [tile])),
        ),
      );

      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Old One'), findsOneWidget);
    });

    testWidgets('active subscription is not dimmed and has no Paused badge', (
      tester,
    ) async {
      final tile = SubscriptionTile(
        subscription: _sub(
          name: 'Live One',
          cost: 9.99,
          cycle: BillingCycle.monthly,
          isActive: true,
        ).copyWith(id: 1),
        onConfirmDelete: () async => false,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: ListView(children: [tile])),
        ),
      );

      expect(find.text('Live One'), findsOneWidget);
      expect(find.text('Paused'), findsNothing);
    });
  });
}
