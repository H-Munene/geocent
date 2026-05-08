import 'package:geocent/database_helper.dart';
import 'package:geocent/models/budget.dart';
import 'package:sqflite/sqflite.dart';

class BudgetRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<void> insertOrUpdateBudget(Budget budget) async {
    final db = await _db.database;
    await db.insert(
      DatabaseHelper.tableBudgets,
      budget.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteBudget(String id) async {
    final db = await _db.database;
    await db.delete(
      DatabaseHelper.tableBudgets,
      where: '${DatabaseHelper.colId} = ?',
      whereArgs: [id],
    );
  }

  Future<List<Budget>> getAllBudgets() async {
    final rows = await _db.rawQuery(
      DatabaseHelper.tableBudgets,
      orderBy: '${DatabaseHelper.colUpdatedAt} DESC',
    );
    return rows.map(Budget.fromMap).toList();
  }

  Future<List<Budget>> getBudgetsByPeriod(String period) async {
    final rows = await _db.rawQuery(
      DatabaseHelper.tableBudgets,
      where: '${DatabaseHelper.colPeriod} = ?',
      whereArgs: [period.toLowerCase()],
      orderBy: '${DatabaseHelper.colUpdatedAt} DESC',
    );
    return rows.map(Budget.fromMap).toList();
  }
}
