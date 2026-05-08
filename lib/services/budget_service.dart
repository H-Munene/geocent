import 'package:flutter/cupertino.dart';
import 'package:geocent/models/budget.dart';
import 'package:geocent/models/budget_progress.dart';
import 'package:geocent/repositories/budget_repository.dart';
import 'package:geocent/repositories/transaction_repository.dart';
import 'package:uuid/uuid.dart';

class BudgetService extends ChangeNotifier {
  final BudgetRepository _budgetRepo = BudgetRepository();
  final TransactionRepository _txRepo = TransactionRepository();

  List<Budget> _budgets = [];
  bool _isLoading = false;

  List<Budget> get budgets => _budgets;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    await refresh();
  }

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    _budgets = await _budgetRepo.getAllBudgets();

    _isLoading = false;
    notifyListeners();
  }

  Future<List<BudgetProgress>> getBudgetProgress(String period) async {
    final budgetsInPeriod = _budgets
        .where((b) => b.period == period.toLowerCase())
        .toList();
    if (budgetsInPeriod.isEmpty) return [];

    final DateTime now = DateTime.now();
    final DateTime start;
    final DateTime end = now;

    switch (period.toLowerCase()) {
      case 'daily':
        start = DateTime(now.year, now.month, now.day);
        break;
      case 'weekly':
        final int daysToSubtract = now.weekday == 7 ? 0 : now.weekday;
        final startOfCurrentWeek = now.subtract(Duration(days: daysToSubtract));
        start = DateTime(
          startOfCurrentWeek.year,
          startOfCurrentWeek.month,
          startOfCurrentWeek.day,
        );
        break;
      case 'monthly':
        start = DateTime(now.year, now.month, 1);
        break;
      default:
        start = DateTime(now.year, now.month, now.day);
    }

    final categorySpending = await _txRepo.getCategorySpending(start, end);

    return budgetsInPeriod.map((budget) {
      final spendingMatch = categorySpending.firstWhere(
        (s) => s['category'] == budget.categoryName,
        orElse: () => {'total_amount': 0.0},
      );
      final double totalSpent = (spendingMatch['total_amount'] as num)
          .toDouble();
      final double percentage = (totalSpent / budget.amountLimit).clamp(
        0.0,
        1.1,
      );

      return BudgetProgress(
        categoryName: budget.categoryName,
        amountLimit: budget.amountLimit,
        totalSpentInPeriod: totalSpent,
        percentageUsed: percentage,
        budget: budget,
      );
    }).toList();
  }

  Future<void> addOrUpdateBudget({
    required String categoryName,
    required double amountLimit,
    required String period,
  }) async {
    // Check if budget for this category already exists to update it
    final existing = _budgets.firstWhere(
      (b) => b.categoryName == categoryName,
      orElse: () => Budget(
        id: const Uuid().v4(),
        categoryName: categoryName,
        amountLimit: amountLimit,
        period: period.toLowerCase(),
        updatedAt: DateTime.now(),
      ),
    );

    final budget = existing.copyWith(
      amountLimit: amountLimit,
      period: period.toLowerCase(),
      updatedAt: DateTime.now(),
    );

    await _budgetRepo.insertOrUpdateBudget(budget);
    await refresh();
  }

  Future<void> deleteBudget(String id) async {
    await _budgetRepo.deleteBudget(id);
    await refresh();
  }
}
