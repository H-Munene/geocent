import 'package:geocent/database_helper.dart';
import 'package:geocent/models/category_analytics.dart';
import 'package:sqflite/sqflite.dart';

import '../models/app_transaction.dart';

class TransactionRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<CategoryAnalytics>> getCategoryComparison() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
          ${DatabaseHelper.colCategory} as category,
          SUM(CASE WHEN date(${DatabaseHelper.colTimestamp}, 'localtime') = date('now', 'localtime') THEN ${DatabaseHelper.colAmount} ELSE 0 END) as today_total,
          SUM(CASE WHEN date(${DatabaseHelper.colTimestamp}, 'localtime') = date('now', '-1 day', 'localtime') THEN ${DatabaseHelper.colAmount} ELSE 0 END) as yesterday_total
      FROM ${DatabaseHelper.tableTransactions}
      WHERE ${DatabaseHelper.colCategory} IS NOT NULL
      GROUP BY ${DatabaseHelper.colCategory}
      HAVING today_total > 0 OR yesterday_total > 0
    ''');

    return maps.map((m) {
      return CategoryAnalytics(
        category: m['category'] as String,
        todayTotal: (m['today_total'] as num).toDouble(),
        yesterdayTotal: (m['yesterday_total'] as num).toDouble(),
      );
    }).toList();
  }

  Future<void> save(AppTransaction tx) async {
    // Auto-categorize if no category is provided
    if (tx.category == null) {
      final String? previousCategory = await getMerchantCategory(tx.merchant);
      if (previousCategory != null) {
        tx = tx.copyWith(category: previousCategory);
      }
    }
    await _db.rawInsert(DatabaseHelper.tableTransactions, tx.toMap());
  }

  Future<void> updateLocation(
    String id,
    double latitude,
    double longitude,
  ) async {
    await _db.rawUpdate(
      DatabaseHelper.tableTransactions,
      {
        DatabaseHelper.colLatitude: latitude,
        DatabaseHelper.colLongitude: longitude,
      },
      '${DatabaseHelper.colId} = ?',
      [id],
    );
  }

  Future<void> updateCategory(String id, String category) async {
    await _db.rawUpdate(
      DatabaseHelper.tableTransactions,
      {DatabaseHelper.colCategory: category},
      '${DatabaseHelper.colId} = ?',
      [id],
    );

    // Auto-learn: Associate this merchant with the new category
    final rows = await _db.rawQuery(
      DatabaseHelper.tableTransactions,
      where: '${DatabaseHelper.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final String merchant = rows.first[DatabaseHelper.colMerchant] as String;
      await upsertMerchantCategory(merchant, category);
    }
  }

  Future<void> updateCategories(List<String> ids, String category) async {
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(',');
    await _db.rawUpdate(
      DatabaseHelper.tableTransactions,
      {DatabaseHelper.colCategory: category},
      '${DatabaseHelper.colId} IN ($placeholders)',
      ids,
    );

    // Auto-learn for all unique merchants in the batch
    final rows = await _db.rawQuery(
      DatabaseHelper.tableTransactions,
      where: '${DatabaseHelper.colId} IN ($placeholders)',
      whereArgs: ids,
    );
    final uniqueMerchants = rows
        .map((r) => r[DatabaseHelper.colMerchant] as String)
        .toSet();

    for (final merchant in uniqueMerchants) {
      await upsertMerchantCategory(merchant, category);
    }
  }

  Future<List<AppTransaction>> loadAll() async {
    final rows = await _db.rawQuery(
      DatabaseHelper.tableTransactions,
      orderBy: '${DatabaseHelper.colTimestamp} DESC',
    );
    return rows.map(AppTransaction.fromMap).toList();
  }

  Future<List<AppTransaction>> loadMapped() async {
    final rows = await _db.rawQuery(
      DatabaseHelper.tableTransactions,
      where:
          '${DatabaseHelper.colLatitude} IS NOT NULL AND ${DatabaseHelper.colLongitude} IS NOT NULL',
      orderBy: '${DatabaseHelper.colTimestamp} DESC',
    );
    return rows.map(AppTransaction.fromMap).toList();
  }

  Future<List<AppTransaction>> loadActionable() async {
    final rows = await _db.rawQuery(
      DatabaseHelper.tableTransactions,
      where:
          '${DatabaseHelper.colLatitude} IS NULL OR ${DatabaseHelper.colCategory} IS NULL',
      orderBy: '${DatabaseHelper.colTimestamp} DESC',
    );
    return rows.map(AppTransaction.fromMap).toList();
  }

  Future<List<AppTransaction>> loadFiltered({
    required String filter,
    int limit = 20,
    int offset = 0,
    String? searchQuery, // Add this parameter
  }) async {
    final db = await _db.database;
    List<String> conditions = [];
    List<String> whereArgs = [];

    // Add filter conditions
    switch (filter) {
      case 'mapping':
        conditions.add('(${DatabaseHelper.colLatitude} IS NULL)');
        break;
      case 'categorization':
        conditions.add(
          '(${DatabaseHelper.colCategory} IS NULL AND ${DatabaseHelper.colLatitude} IS NOT NULL)',
        );
        break;
      case 'all':
        conditions.add(
          '(${DatabaseHelper.colLatitude} IS NULL OR ${DatabaseHelper.colCategory} IS NULL)',
        );
        break;
    }

    // Add search query to conditions
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final sanitizedQuery = searchQuery.toLowerCase().replaceAll(
        RegExp(r'[,\-\s]'),
        '',
      );
      conditions.add(
        "REPLACE(REPLACE(REPLACE(LOWER(${DatabaseHelper.colRawMessage}), ',', ''), '-', ''), ' ', '') LIKE ?",
      );
      whereArgs.add('%$sanitizedQuery%');
    }

    String? finalWhereClause;
    if (conditions.isNotEmpty) {
      finalWhereClause = conditions.join(' AND ');
    }

    final maps = await db.query(
      DatabaseHelper.tableTransactions,
      orderBy: '${DatabaseHelper.colTimestamp} DESC',
      where: finalWhereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      limit: limit,
      offset: offset,
    );

    return List.generate(maps.length, (i) {
      return AppTransaction.fromMap(maps[i]);
    });
  }

  Future<List<AppTransaction>> loadByPeriod(String period) async {
    final DateTime now = DateTime.now();
    final DateTime from;
    switch (period.toLowerCase()) {
      case 'today':
        from = DateTime(now.year, now.month, now.day);
        break;
      case 'this week':
        final monday = now.subtract(Duration(days: now.weekday - 1));
        from = DateTime(monday.year, monday.month, monday.day);
        break;
      case 'month':
        from = DateTime(now.year, now.month, 1);
        break;
      default:
        from = DateTime(now.year, now.month, now.day);
    }
    final rows = await _db.rawQuery(
      DatabaseHelper.tableTransactions,
      where: '${DatabaseHelper.colTimestamp} >= ?',
      whereArgs: [from.toIso8601String()],
      orderBy: '${DatabaseHelper.colTimestamp} DESC',
    );
    return rows.map(AppTransaction.fromMap).toList();
  }

  Future<bool> exists(String id) async {
    final rows = await _db.rawQuery(
      DatabaseHelper.tableTransactions,
      where: '${DatabaseHelper.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<double> getLimit(String period) async {
    final rows = await _db.rawQuery(
      DatabaseHelper.tableSpendingLimits,
      where: '${DatabaseHelper.colPeriod} = ?',
      whereArgs: [period.toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) return 0.0;
    return (rows.first[DatabaseHelper.colLimitAmount] as num).toDouble();
  }

  Future<List<AppTransaction>> searchTransactions(String query) async {
    final sanitizedQuery = query.toLowerCase().replaceAll(
      RegExp(r'[,\-\s]'),
      '',
    );
    final rows = await _db.rawQuery(
      DatabaseHelper.tableTransactions,
      where:
          '${DatabaseHelper.colId} LIKE ? OR REPLACE(REPLACE(REPLACE(LOWER(${DatabaseHelper.colMerchant}), ",", ""), "-", ""), " ", "") LIKE ? OR ${DatabaseHelper.colSource} LIKE ? OR CAST(${DatabaseHelper.colAmount} AS TEXT) LIKE ? OR REPLACE(REPLACE(REPLACE(LOWER(${DatabaseHelper.colRawMessage}), ",", ""), "-", ""), " ", "") LIKE ?',
      whereArgs: [
        '%$query%',
        '%$sanitizedQuery%',
        '%$query%',
        '%$query%',
        '%$sanitizedQuery%',
      ],
      orderBy: '${DatabaseHelper.colTimestamp} DESC',
    );
    return rows.map(AppTransaction.fromMap).toList();
  }

  Future<List<AppTransaction>> loadByCategory(String category) async {
    final rows = await _db.rawQuery(
      DatabaseHelper.tableTransactions,
      where: '${DatabaseHelper.colCategory} = ?',
      whereArgs: [category],
      orderBy: '${DatabaseHelper.colTimestamp} DESC',
    );
    return rows.map(AppTransaction.fromMap).toList();
  }

  Future<Map<String, double>> getAllLimits() async {
    final rows = await _db.rawQuery(DatabaseHelper.tableSpendingLimits);
    return {
      for (final row in rows)
        row[DatabaseHelper.colPeriod] as String:
            (row[DatabaseHelper.colLimitAmount] as num).toDouble(),
    };
  }

  Future<void> setLimit(String period, double amount) async {
    await _db.rawUpdate(
      DatabaseHelper.tableSpendingLimits,
      {
        DatabaseHelper.colPeriod: period.toLowerCase(),
        DatabaseHelper.colLimitAmount: amount,
        DatabaseHelper.colUpdatedAt: DateTime.now().toIso8601String(),
      },
      '${DatabaseHelper.colPeriod} = ?',
      [period.toLowerCase()],
    );
  }

  // ── Merchant Categories ──────────────────────────────────────────────────

  Future<String?> getMerchantCategory(String merchantName) async {
    final rows = await _db.rawQuery(
      DatabaseHelper.tableMerchantCategories,
      where: '${DatabaseHelper.colMerchantName} = ?',
      whereArgs: [merchantName],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first[DatabaseHelper.colCategoryName] as String?;
  }

  Future<void> upsertMerchantCategory(
    String merchantName,
    String categoryName,
  ) async {
    final db = await _db.database;
    await db.insert(
      DatabaseHelper.tableMerchantCategories,
      {
        DatabaseHelper.colMerchantName: merchantName,
        DatabaseHelper.colCategoryName: categoryName,
        DatabaseHelper.colUpdatedAt: DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
