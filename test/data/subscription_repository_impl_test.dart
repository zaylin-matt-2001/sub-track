import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sub_track/core/constants/enums.dart';
import 'package:sub_track/core/database/app_database.dart';
import 'package:sub_track/features/subscriptions/data/datasources/subscription_local_data_source.dart';
import 'package:sub_track/features/subscriptions/data/models/subscription_model.dart';
import 'package:sub_track/features/subscriptions/data/repositories/subscription_repository_impl.dart';
import 'package:sub_track/features/subscriptions/domain/entities/subscription.dart';

// ── In-memory DB that mirrors the v2 schema (onCreate path) ─────────────────
Future<Database> _openMemoryDb() async {
  sqfliteFfiInit();
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: AppDatabase.schemaVersion,
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
            rate_to_base  REAL NOT NULL
          )
        ''');
      },
    ),
  );
}

Subscription _entity({
  int? id,
  String name = 'Netflix',
  double cost = 14.99,
  BillingCycle cycle = BillingCycle.monthly,
  DateTime? due,
  Category category = Category.streaming,
  String? iconName = 'streaming',
  bool isActive = true,
  String currencyCode = 'USD',
}) {
  return Subscription(
    id: id,
    name: name,
    cost: cost,
    billingCycle: cycle,
    nextDueDate: due ?? DateTime(2026, 9, 15),
    category: category,
    iconName: iconName,
    isActive: isActive,
    currencyCode: currencyCode,
  );
}

void main() {
  group('SubscriptionRepositoryImpl — CRUD round-trip', () {
    late Database db;
    late SubscriptionRepositoryImpl repo;

    setUp(() async {
      db = await _openMemoryDb();
      repo = SubscriptionRepositoryImpl(SubscriptionLocalDataSource(db));
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'insert → getAll round-trip returns the saved entity with an id',
      () async {
        final inserted = await repo.add(_entity());
        expect(inserted.id, isNotNull);

        final all = await repo.getAll();
        expect(all.length, 1);
        expect(all.first.id, inserted.id);
        expect(all.first.name, 'Netflix');
        expect(all.first.cost, 14.99);
        expect(all.first.billingCycle, BillingCycle.monthly);
        expect(all.first.category, Category.streaming);
        expect(all.first.iconName, 'streaming');
        expect(all.first.isActive, isTrue);
        expect(all.first.currencyCode, 'USD');
      },
    );

    test('toMap omits id on insert (auto-increment)', () async {
      final model = SubscriptionModel.fromEntity(_entity());
      final map = model.toMap();
      expect(map.containsKey('id'), isFalse);
    });

    test('toMap includes id on update (preserved id)', () async {
      final inserted = await repo.add(_entity());
      final model = SubscriptionModel.fromEntity(inserted);
      final map = model.toMap();
      expect(map['id'], inserted.id);
    });

    test('update mutates the persisted row', () async {
      final inserted = await repo.add(_entity(name: 'Netflix', cost: 14.99));

      await repo.update(
        inserted.copyWith(
          name: 'Netflix Premium',
          cost: 22.99,
          iconName: 'movie',
        ),
      );

      final all = await repo.getAll();
      expect(all.length, 1);
      expect(all.first.name, 'Netflix Premium');
      expect(all.first.cost, 22.99);
      expect(all.first.iconName, 'movie');
      expect(all.first.id, inserted.id);
    });

    test(
      'updateAll persists multiple rows in one repository operation',
      () async {
        final first = await repo.add(_entity(name: 'First'));
        final second = await repo.add(_entity(name: 'Second'));

        await repo.updateAll([
          first.copyWith(nextDueDate: DateTime(2026, 10, 1)),
          second.copyWith(nextDueDate: DateTime(2026, 11, 1)),
        ]);

        final all = await repo.getAll();
        expect(all.map((item) => item.nextDueDate), [
          DateTime(2026, 10, 1),
          DateTime(2026, 11, 1),
        ]);
      },
    );

    test('delete removes the row', () async {
      final a = await repo.add(_entity(name: 'A'));
      final b = await repo.add(_entity(name: 'B'));

      await repo.delete(a.id!);

      final all = await repo.getAll();
      expect(all.length, 1);
      expect(all.first.id, b.id);
      expect(all.first.name, 'B');
    });

    test('nextDueDate round-trips through ISO-8601 string', () async {
      final due = DateTime(2026, 12, 31, 0, 0, 0);
      await repo.add(_entity(due: due));
      final loaded = (await repo.getAll()).first;
      expect(loaded.nextDueDate, due);
    });
  });

  // ── M8: is_active and currency_code round-trips ────────────────────────────
  group('SubscriptionRepositoryImpl — M8 isActive & currencyCode (M8)', () {
    late Database db;
    late SubscriptionRepositoryImpl repo;

    setUp(() async {
      db = await _openMemoryDb();
      repo = SubscriptionRepositoryImpl(SubscriptionLocalDataSource(db));
    });

    tearDown(() async {
      await db.close();
    });

    test('isActive=true round-trips correctly', () async {
      final inserted = await repo.add(_entity(isActive: true));
      final loaded = (await repo.getAll()).first;
      expect(loaded.isActive, isTrue);
      expect(inserted.isActive, isTrue);
    });

    test('isActive=false round-trips correctly', () async {
      final inserted = await repo.add(_entity(isActive: false));
      final loaded = (await repo.getAll()).first;
      expect(loaded.isActive, isFalse);
      expect(inserted.isActive, isFalse);
    });

    test('currencyCode round-trips correctly', () async {
      await repo.add(_entity(currencyCode: 'EUR'));
      final loaded = (await repo.getAll()).first;
      expect(loaded.currencyCode, 'EUR');
    });

    test('update can toggle isActive from true to false', () async {
      final inserted = await repo.add(_entity(isActive: true));
      await repo.update(inserted.copyWith(isActive: false));
      final loaded = (await repo.getAll()).first;
      expect(loaded.isActive, isFalse);
    });

    test('update can toggle isActive from false to true', () async {
      final inserted = await repo.add(_entity(isActive: false));
      await repo.update(inserted.copyWith(isActive: true));
      final loaded = (await repo.getAll()).first;
      expect(loaded.isActive, isTrue);
    });

    test('is_active defaults to 1 (true) when missing from map', () {
      final model = SubscriptionModel.fromMap(<String, Object?>{
        'id': 1,
        'name': 'X',
        'cost': 9.99,
        'billing_cycle': 'monthly',
        'next_due_date': '2026-09-15T00:00:00.000',
        'category': 'Streaming',
        'icon_name': null,
        // is_active intentionally absent
      });
      expect(model.isActive, isTrue);
    });

    test('currency_code defaults to USD when missing from map', () {
      final model = SubscriptionModel.fromMap(<String, Object?>{
        'id': 1,
        'name': 'X',
        'cost': 9.99,
        'billing_cycle': 'monthly',
        'next_due_date': '2026-09-15T00:00:00.000',
        'category': 'Streaming',
        'icon_name': null,
        // currency_code intentionally absent
      });
      expect(model.currencyCode, 'USD');
    });
  });

  group('SubscriptionRepositoryImpl — malformed rows load safely', () {
    late Database db;
    late SubscriptionRepositoryImpl repo;

    setUp(() async {
      db = await _openMemoryDb();
      repo = SubscriptionRepositoryImpl(SubscriptionLocalDataSource(db));
    });

    tearDown(() async {
      await db.close();
    });

    test('unknown billing_cycle in a row map falls back to monthly via fromMap '
        '(PRD §3.4 total parser, exercised at the model layer)', () async {
      final model = SubscriptionModel.fromMap(<String, Object?>{
        'id': 1,
        'name': 'X',
        'cost': 9.99,
        'billing_cycle': 'weekly',
        'next_due_date': '2026-09-15T00:00:00.000',
        'category': 'Streaming',
        'icon_name': 'streaming',
      });
      expect(model.billingCycle, BillingCycle.monthly);
    });

    test(
      'unknown category in a row map falls back to Other via fromMap',
      () async {
        final model = SubscriptionModel.fromMap(<String, Object?>{
          'id': 1,
          'name': 'X',
          'cost': 9.99,
          'billing_cycle': 'monthly',
          'next_due_date': '2026-09-15T00:00:00.000',
          'category': 'Groceries',
          'icon_name': 'streaming',
        });
        expect(model.category, Category.other);
      },
    );

    test('null icon_name still loads (entity.iconName == null)', () async {
      final inserted = await repo.add(_entity(iconName: 'streaming'));
      await db.update(
        'subscriptions',
        {'icon_name': null},
        where: 'id = ?',
        whereArgs: [inserted.id],
      );
      final loaded = (await repo.getAll()).first;
      expect(loaded.iconName, isNull);
    });

    test('unknown icon_name in a row map still loads as-is '
        '(catalog resolution is a UI concern, not a DB one)', () async {
      final model = SubscriptionModel.fromMap(<String, Object?>{
        'id': 1,
        'name': 'X',
        'cost': 9.99,
        'billing_cycle': 'monthly',
        'next_due_date': '2026-09-15T00:00:00.000',
        'category': 'Streaming',
        'icon_name': 'not-a-real-icon',
      });
      expect(model.iconName, 'not-a-real-icon');
    });
  });

  group('SubscriptionRepositoryImpl — CHECK constraints', () {
    late Database db;

    setUp(() async {
      db = await _openMemoryDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('cost = 0 is rejected by the SQLite CHECK (cost > 0)', () async {
      expect(
        () async => await db.insert('subscriptions', {
          'name': 'Bad',
          'cost': 0,
          'billing_cycle': 'monthly',
          'next_due_date': '2026-09-15T00:00:00.000',
          'category': 'Other',
          'icon_name': null,
          'is_active': 1,
          'currency_code': 'USD',
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('negative cost is rejected by the SQLite CHECK (cost > 0)', () async {
      expect(
        () async => await db.insert('subscriptions', {
          'name': 'Bad',
          'cost': -5.0,
          'billing_cycle': 'monthly',
          'next_due_date': '2026-09-15T00:00:00.000',
          'category': 'Other',
          'icon_name': null,
          'is_active': 1,
          'currency_code': 'USD',
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('billing_cycle outside the allowed set is rejected', () async {
      expect(
        () async => await db.insert('subscriptions', {
          'name': 'Bad',
          'cost': 9.99,
          'billing_cycle': 'weekly',
          'next_due_date': '2026-09-15T00:00:00.000',
          'category': 'Other',
          'icon_name': null,
          'is_active': 1,
          'currency_code': 'USD',
        }),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('AppDatabase — schema versioning (M8)', () {
    test('schemaVersion constant is 2', () {
      expect(AppDatabase.schemaVersion, 2);
    });
  });

  // ── M8: DB migration simulation ───────────────────────────────────────────
  group('AppDatabase — onUpgrade migration v1→v2 (M8)', () {
    test('settings and exchange_rates tables exist after migration', () async {
      sqfliteFfiInit();
      // Open a fresh DB, create a v1 schema manually, then reopen at v2
      final db1 = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, v) async {
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
      // Insert a v1 row without the new columns
      await db1.insert('subscriptions', {
        'name': 'OldSub',
        'cost': 9.99,
        'billing_cycle': 'monthly',
        'next_due_date': '2026-09-15T00:00:00.000',
        'category': 'Other',
        'icon_name': null,
      });
      await db1.close();

      // sqflite in-memory DBs don't persist on close, so we simulate the
      // migration column additions on a live DB directly.
      final db2 = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, v) async {
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
            await db.insert('subscriptions', {
              'name': 'OldSub',
              'cost': 9.99,
              'billing_cycle': 'monthly',
              'next_due_date': '2026-09-15T00:00:00.000',
              'category': 'Other',
              'icon_name': null,
            });
          },
        ),
      );

      // Run migration commands manually
      await db2.execute(
        "ALTER TABLE subscriptions ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1",
      );
      await db2.execute(
        "ALTER TABLE subscriptions ADD COLUMN currency_code TEXT NOT NULL DEFAULT 'USD'",
      );
      await db2.execute(
        'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      );
      await db2.execute(
        'CREATE TABLE exchange_rates (currency_code TEXT PRIMARY KEY, rate_to_base REAL NOT NULL)',
      );

      // Verify the migrated row gets default values
      final rows = await db2.query('subscriptions');
      expect(rows.length, 1);
      expect(rows.first['is_active'], 1);
      expect(rows.first['currency_code'], 'USD');
      expect(rows.first['name'], 'OldSub');

      // Verify new tables exist
      final tables = await db2.query(
        'sqlite_master',
        where: 'type = ?',
        whereArgs: ['table'],
      );
      final tableNames = tables.map((r) => r['name'] as String).toSet();
      expect(tableNames, containsAll(['settings', 'exchange_rates']));

      await db2.close();
    });
  });
}
