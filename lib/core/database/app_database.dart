import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const String fileName = 'subtrack.db';
  static const int schemaVersion = 2;

  static const String _createSubscriptionsV2 = '''
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
  ''';

  static const String _createSettings = '''
    CREATE TABLE settings (
      key   TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''';

  static const String _createExchangeRates = '''
    CREATE TABLE exchange_rates (
      currency_code TEXT PRIMARY KEY,
      rate_to_base  REAL NOT NULL CHECK (rate_to_base > 0)
    )
  ''';

  static Future<Database> open({
    String? overrideDirectory,
    DatabaseFactory? factory,
  }) async {
    final dbFactory = factory ?? databaseFactory;
    final dir = overrideDirectory ?? await getDatabasesPath();
    final path = p.join(dir, fileName);
    return dbFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: (db, version) async {
          await db.execute(_createSubscriptionsV2);
          await db.execute(_createSettings);
          await db.execute(_createExchangeRates);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              'ALTER TABLE subscriptions ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
            );
            await db.execute(
              'ALTER TABLE subscriptions ADD COLUMN currency_code TEXT NOT NULL DEFAULT \'USD\'',
            );
            await db.execute(_createSettings);
            await db.execute(_createExchangeRates);
          }
        },
      ),
    );
  }

  /// Replays the v1→v2 upgrade on an existing v1 database opened with a
  /// raw [Database] handle (used by migration tests). Performs only the
  /// destructive-but-isolated upgrade steps; does not touch rows beyond
  /// adding the new columns.
  static Future<void> applyV2Upgrade(Database db) async {
    await db.execute(
      'ALTER TABLE subscriptions ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
    );
    await db.execute(
      'ALTER TABLE subscriptions ADD COLUMN currency_code TEXT NOT NULL DEFAULT \'USD\'',
    );
    await db.execute(_createSettings);
    await db.execute(_createExchangeRates);
  }
}
