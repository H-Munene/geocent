import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static const String _dbName = 'geocent.db';
  static const int _dbVersion = 2;

  // Table & column constants
  static const String tableTransactions = 'transactions';
  static const String colId = 'id';
  static const String colAmount = 'amount';
  static const String colMerchant = 'merchant';
  static const String colRawMessage = 'raw_message';
  static const String colTimestamp = 'timestamp';
  static const String colBalanceAfter = 'balance_after';
  static const String colSource = 'source';
  static const String colType = 'type';
  static const String colLatitude = 'latitude';
  static const String colLongitude = 'longitude';
  static const String colCategory = 'category';

  static const String tableSpendingLimits = 'spending_limits';
  static const String colPeriod = 'period'; // 'daily' | 'weekly' | 'monthly'
  static const String colLimitAmount = 'limit_amount';
  static const String colUpdatedAt = 'updated_at';

  // Singleton
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _db;
  static Completer<Database>? _dbCompleter;

  Future<Database> get database async {
    if (_db != null) return _db!;

    if (_dbCompleter != null) return _dbCompleter!.future;

    _dbCompleter = Completer<Database>();
    try {
      _db = await _initDb();
      _dbCompleter!.complete(_db!);
      _dbCompleter = null;
      return _db!;
    } catch (e) {
      _dbCompleter!.completeError(e);
      _dbCompleter = null;
      rethrow;
    }
  }

  Future<Database> _initDb() async {
    final String path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // ── Transactions ─────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE $tableTransactions (
        $colId          TEXT    PRIMARY KEY,
        $colAmount      REAL    NOT NULL,
        $colMerchant    TEXT    NOT NULL,
        $colRawMessage  TEXT    NOT NULL,
        $colTimestamp   TEXT    NOT NULL,
        $colBalanceAfter REAL,
        $colSource      TEXT    NOT NULL CHECK($colSource IN ('mpesa','equity')),
        $colType        TEXT    NOT NULL CHECK($colType IN ('sent','payment','received','unknown')),
        $colLatitude    REAL,
        $colLongitude   REAL,
        $colCategory    TEXT
      )
    ''');

    // Index for fast period-based queries (today / this week / month)
    await db.execute('''
      CREATE INDEX idx_transactions_timestamp
        ON $tableTransactions ($colTimestamp DESC)
    ''');

    // ── Spending limits ───────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE $tableSpendingLimits (
        $colPeriod       TEXT PRIMARY KEY
                              CHECK($colPeriod IN ('daily','weekly','monthly')),
        $colLimitAmount  REAL NOT NULL,
        $colUpdatedAt    TEXT NOT NULL
      )
    ''');
  }

  // Extend schema here in future versions without wiping data
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE $tableTransactions ADD COLUMN $colCategory TEXT',
      );
    }
  }

  // ── Low-level helpers ──────────────────────────────────────────────────────

  Future<int> rawInsert(String table, Map<String, dynamic> row) async {
    final Database db = await database;
    return db.insert(
      table,
      row,
      conflictAlgorithm: ConflictAlgorithm.ignore, // skip duplicates by id
    );
  }

  Future<int> rawUpdate(
    String table,
    Map<String, dynamic> values,
    String where,
    List<dynamic> whereArgs,
  ) async {
    final Database db = await database;
    return db.update(table, values, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> rawQuery(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final Database db = await database;
    return db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  Future<void> closeDb() async {
    final Database? db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
