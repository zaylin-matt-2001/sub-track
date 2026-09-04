import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sub_track/core/constants/enums.dart';
import 'package:sub_track/core/database/app_database.dart';
import 'package:sub_track/features/subscriptions/data/datasources/subscription_local_data_source.dart';
import 'package:sub_track/features/subscriptions/data/models/subscription_model.dart';
import 'package:sub_track/features/subscriptions/data/repositories/subscription_repository_impl.dart';
import 'package:sub_track/features/subscriptions/domain/entities/subscription.dart';

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
            icon_name     TEXT
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
}) {
  return Subscription(
    id: id,
    name: name,
    cost: cost,
    billingCycle: cycle,
    nextDueDate: due ?? DateTime(2026, 9, 15),
    category: category,
    iconName: iconName,
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

    test('insert → getAll round-trip returns the saved entity with an id',
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
    });

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

      await repo.update(inserted.copyWith(
        name: 'Netflix Premium',
        cost: 22.99,
        iconName: 'movie',
      ));

      final all = await repo.getAll();
      expect(all.length, 1);
      expect(all.first.name, 'Netflix Premium');
      expect(all.first.cost, 22.99);
      expect(all.first.iconName, 'movie');
      expect(all.first.id, inserted.id);
    });

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

    test(
      'unknown billing_cycle in a row map falls back to monthly via fromMap '
      '(PRD §3.4 total parser, exercised at the model layer)',
      () async {
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
      },
    );

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

    test(
      'unknown icon_name in a row map still loads as-is '
      '(catalog resolution is a UI concern, not a DB one)',
      () async {
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
      },
    );
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
        }),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('AppDatabase — schema versioning', () {
    test('schemaVersion constant is 1', () {
      expect(AppDatabase.schemaVersion, 1);
    });
  });
}
