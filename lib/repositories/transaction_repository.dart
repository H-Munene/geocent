// import 'package:mapbox_tut/database_helper.dart';

// import '../database/database_helper.dart';
// import '../models/transaction.dart';

// class TransactionRepository {
//   final DatabaseHelper _db = DatabaseHelper.instance;

//   // ── Transactions ───────────────────────────────────────────────────────────

//   /// Insert a new transaction. Silently ignores duplicates (same id).
//   Future<void> save(Transaction tx) async {
//     await _db.rawInsert(DatabaseHelper.tableTransactions, tx.toMap());
//   }

//   /// Attach GPS coordinates to an already-saved transaction.
//   Future<void> updateLocation(
//       String id, double latitude, double longitude) async {
//     await _db.rawUpdate(
//       DatabaseHelper.tableTransactions,
//       {
//         DatabaseHelper.colLatitude: latitude,
//         DatabaseHelper.colLongitude: longitude,
//       },
//       '${DatabaseHelper.colId} = ?',
//       [id],
//     );
//   }

//   /// All transactions, newest first.
//   Future<List<Transaction>> loadAll() async {
//     final rows = await _db.rawQuery(
//       DatabaseHelper.tableTransactions,
//       orderBy: '${DatabaseHelper.colTimestamp} DESC',
//     );
//     return rows.map(Transaction.fromMap).toList();
//   }

//   /// Transactions that have GPS coordinates — used to populate map annotations.
//   Future<List<Transaction>> loadMapped() async {
//     final rows = await _db.rawQuery(
//       DatabaseHelper.tableTransactions,
//       where:
//           '${DatabaseHelper.colLatitude} IS NOT NULL AND ${DatabaseHelper.colLongitude} IS NOT NULL',
//       orderBy: '${DatabaseHelper.colTimestamp} DESC',
//     );
//     return rows.map(Transaction.fromMap).toList();
//   }

//   /// Transactions filtered by period — drives DynamicIsland spent value.
//   Future<List<Transaction>> loadByPeriod(String period) async {
//     final DateTime now = DateTime.now();
//     final DateTime from;

//     switch (period.toLowerCase()) {
//       case 'today':
//         from = DateTime(now.year, now.month, now.day);
//         break;
//       case 'this week':
//         // Monday of the current week
//         from = now.subtract(Duration(days: now.weekday - 1));
//         from = DateTime(from.year, from.month, from.day);
//         break;
//       case 'month':
//         from = DateTime(now.year, now.month, 1);
//         break;
//       default:
//         from = DateTime(now.year, now.month, now.day); // fallback: today
//     }

//     final rows = await _db.rawQuery(
//       DatabaseHelper.tableTransactions,
//       where: '${DatabaseHelper.colTimestamp} >= ?',
//       whereArgs: [from.toIso8601String()],
//       orderBy: '${DatabaseHelper.colTimestamp} DESC',
//     );
//     return rows.map(Transaction.fromMap).toList();
//   }

//   /// Total amount spent in a given period.
//   Future<double> totalSpent(String period) async {
//     final transactions = await loadByPeriod(period);
//     return transactions.fold(0.0, (sum, tx) => sum + tx.amount);
//   }

//   /// Check if a transaction id already exists (prevents double-processing SMS).
//   Future<bool> exists(String id) async {
//     final rows = await _db.rawQuery(
//       DatabaseHelper.tableTransactions,
//       where: '${DatabaseHelper.colId} = ?',
//       whereArgs: [id],
//       limit: 1,
//     );
//     return rows.isNotEmpty;
//   }

//   // ── Spending limits ────────────────────────────────────────────────────────

//   /// Returns the spending limit for a given period ('daily','weekly','monthly').
//   Future<double> getLimit(String period) async {
//     final rows = await _db.rawQuery(
//       DatabaseHelper.tableSpendingLimits,
//       where: '${DatabaseHelper.colPeriod} = ?',
//       whereArgs: [period.toLowerCase()],
//       limit: 1,
//     );
//     if (rows.isEmpty) return 0.0;
//     return rows.first[DatabaseHelper.colLimitAmount] as double;
//   }

//   /// Returns limits for all three periods at once.
//   Future<Map<String, double>> getAllLimits() async {
//     final rows = await _db.rawQuery(DatabaseHelper.tableSpendingLimits);
//     return {
//       for (final row in rows)
//         row[DatabaseHelper.colPeriod] as String:
//             row[DatabaseHelper.colLimitAmount] as double,
//     };
//   }

//   /// Update a spending limit. Period must be 'daily', 'weekly', or 'monthly'.
//   Future<void> setLimit(String period, double amount) async {
//     await _db.rawUpdate(
//       DatabaseHelper.tableSpendingLimits,
//       {
//         DatabaseHelper.colLimitAmount: amount,
//         DatabaseHelper.colUpdatedAt: DateTime.now().toIso8601String(),
//       },
//       '${DatabaseHelper.colPeriod} = ?',
//       [period.toLowerCase()],
//     );
//   }
// }

// lib/repositories/transaction_repository.dart
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
    // Note: sqflite rawQuery doesn't have offset in parameters, but we can use it in orderBy or custom query if needed.
    // Actually, db.query HAS offset. Let's check DatabaseHelper.
    // DatabaseHelper.rawQuery wraps db.query. Let's see if it supports offset.
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
