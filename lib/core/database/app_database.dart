import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const String fileName = 'subtrack.db';
  static const int schemaVersion = 1;

  static const String _createTableSql = '''
    CREATE TABLE subscriptions (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      name          TEXT    NOT NULL,
      cost          REAL    NOT NULL CHECK (cost > 0),
      billing_cycle TEXT    NOT NULL CHECK (billing_cycle IN ('monthly','yearly')),
      next_due_date TEXT    NOT NULL,
      category      TEXT    NOT NULL,
      icon_name     TEXT
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
          await db.execute(_createTableSql);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
        },
      ),
    );
  }
}
