import 'package:mapbox_tut/database_helper.dart';
import 'package:sqflite/sqflite.dart';

import '../models/app_transaction.dart';

class TransactionRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<void> save(AppTransaction tx) async {
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
  }) async {
    String? where;
    if (filter == 'mapping') {
      where = '${DatabaseHelper.colLatitude} IS NULL';
    } else if (filter == 'categorization') {
      where =
          '${DatabaseHelper.colCategory} IS NULL AND ${DatabaseHelper.colLatitude} IS NOT NULL';
    } else {
      // 'all' actionable
      where =
          '${DatabaseHelper.colLatitude} IS NULL OR ${DatabaseHelper.colCategory} IS NULL';
    }

    final rows = await _db.rawQuery(
      DatabaseHelper.tableTransactions,
      where: where,
      orderBy: '${DatabaseHelper.colTimestamp} DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(AppTransaction.fromMap).toList();
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

  Future<Map<String, double>> getAllLimits() async {
    final rows = await _db.rawQuery(DatabaseHelper.tableSpendingLimits);
    return {
      for (final row in rows)
        row[DatabaseHelper.colPeriod] as String:
            (row[DatabaseHelper.colLimitAmount] as num).toDouble(),
    };
  }

  Future<void> setLimit(String period, double amount) async {
    final db = await _db.database;
    await db.insert(
      DatabaseHelper.tableSpendingLimits,
      {
        DatabaseHelper.colPeriod: period.toLowerCase(),
        DatabaseHelper.colLimitAmount: amount,
        DatabaseHelper.colUpdatedAt: DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
