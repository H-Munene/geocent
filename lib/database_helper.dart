import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static const String _dbName = 'geocent.db';
  static const int _dbVersion = 8;

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

  static const String tableIgnoredTransactions = 'ignored_transactions';

  static const String tableSpendingLimits = 'spending_limits';
  static const String colPeriod = 'period'; // 'daily' | 'weekly' | 'monthly'
  static const String colLimitAmount = 'limit_amount';
  static const String colUpdatedAt = 'updated_at';

  static const String tableMerchantCategories = 'merchant_categories';
  static const String colMerchantName = 'merchant_name';
  static const String colCategoryName = 'category_name';

  static const String tableBudgets = 'budgets';
  static const String colAmountLimit = 'amount_limit';
  static const String colLastNotifiedThreshold = 'last_notified_threshold';
  static const String colLastNotifiedAt = 'last_notified_at';

  static const String tableHotspots = 'hotspots';
  static const String colStableKey = 'stable_key';
  static const String colRadius = 'radius';
  static const String colAvgSpend = 'avg_spend';
  static const String colTotalSpend = 'total_spend';
  static const String colTransactionCount = 'transaction_count';

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

    // ── Merchant Categories ──────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE $tableMerchantCategories (
        $colMerchantName TEXT PRIMARY KEY,
        $colCategoryName TEXT NOT NULL,
        $colUpdatedAt    TEXT NOT NULL
      )
    ''');

    // ── Budgets ──────────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE $tableBudgets (
        $colId            TEXT PRIMARY KEY,
        $colCategoryName  TEXT UNIQUE NOT NULL,
        $colAmountLimit   REAL NOT NULL,
        $colPeriod        TEXT NOT NULL CHECK($colPeriod IN ('daily','weekly','monthly')),
        $colUpdatedAt     TEXT NOT NULL,
        $colLastNotifiedThreshold INTEGER DEFAULT 0,
        $colLastNotifiedAt        TEXT
      )
    ''');

    // ── Ignored Transactions ──────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE $tableIgnoredTransactions (
        $colId TEXT PRIMARY KEY
      )
    ''');

    // ── Hotspots ──────────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE $tableHotspots (
        $colId              TEXT PRIMARY KEY,
        $colStableKey       TEXT NOT NULL,
        $colLatitude        REAL NOT NULL,
        $colLongitude       REAL NOT NULL,
        $colRadius          REAL NOT NULL,
        $colAvgSpend        REAL NOT NULL,
        $colTotalSpend      REAL NOT NULL,
        $colTransactionCount INTEGER NOT NULL,
        $colLastNotifiedAt  TEXT
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
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE $tableMerchantCategories (
          $colMerchantName TEXT PRIMARY KEY,
          $colCategoryName TEXT NOT NULL,
          $colUpdatedAt    TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE $tableBudgets (
          $colId            TEXT PRIMARY KEY,
          $colCategoryName  TEXT UNIQUE NOT NULL,
          $colAmountLimit   REAL NOT NULL,
          $colPeriod        TEXT NOT NULL CHECK($colPeriod IN ('daily','weekly','monthly')),
          $colUpdatedAt     TEXT NOT NULL
        )
      ''');
    }
    /*
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cached_hotspots (
          id             TEXT PRIMARY KEY,
          name           TEXT NOT NULL,
          latitude       REAL NOT NULL,
          longitude      REAL NOT NULL,
          matched_category TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_metadata (
          id                 INTEGER PRIMARY KEY,
          last_sync_lat        REAL NOT NULL,
          last_sync_lon        REAL NOT NULL,
          last_sync_timestamp  TEXT NOT NULL
        )
      ''');
    }
    */
    if (oldVersion < 6) {
      await db.execute(
        'ALTER TABLE $tableBudgets ADD COLUMN $colLastNotifiedThreshold INTEGER DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE $tableBudgets ADD COLUMN $colLastNotifiedAt TEXT',
      );
    }
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableIgnoredTransactions (
          $colId TEXT PRIMARY KEY
        )
      ''');
    }
    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableHotspots (
          $colId              TEXT PRIMARY KEY,
          $colStableKey       TEXT NOT NULL,
          $colLatitude        REAL NOT NULL,
          $colLongitude       REAL NOT NULL,
          $colRadius          REAL NOT NULL,
          $colAvgSpend        REAL NOT NULL,
          $colTotalSpend      REAL NOT NULL,
          $colTransactionCount INTEGER NOT NULL,
          $colLastNotifiedAt  TEXT
        )
      ''');
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
