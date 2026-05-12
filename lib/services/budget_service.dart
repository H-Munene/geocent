import 'package:flutter/cupertino.dart';
import 'package:geocent/models/budget.dart';
import 'package:geocent/models/budget_progress.dart';
import 'package:geocent/repositories/budget_repository.dart';
import 'package:geocent/repositories/transaction_repository.dart';
import 'package:uuid/uuid.dart';
import 'package:geocent/services/notification_service.dart';

class BudgetService extends ChangeNotifier {
  final BudgetRepository _budgetRepo = BudgetRepository();
  final TransactionRepository _txRepo = TransactionRepository();

  List<Budget> _budgets = [];
  bool _isLoading = false;
  bool _anyExceeded = false;
  final Map<String, bool> _exceededPeriods = {
    'daily': false,
    'weekly': false,
    'monthly': false,
  };

  List<Budget> get budgets => _budgets;
  bool get isLoading => _isLoading;
  bool get anyExceeded => _anyExceeded;

  bool isPeriodExceeded(String period) =>
      _exceededPeriods[period.toLowerCase()] ?? false;

  Future<void> init() async {
    await refresh();
  }

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    _budgets = await _budgetRepo.getAllBudgets();
    await updateExceededStatus();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateExceededStatus() async {
    if (_budgets.isEmpty) {
      bool changed = false;
      if (_anyExceeded) {
        _anyExceeded = false;
        changed = true;
      }
      _exceededPeriods.updateAll((key, value) {
        if (value) changed = true;
        return false;
      });
      if (changed) notifyListeners();
      return;
    }

    final allPeriods = ['daily', 'weekly', 'monthly'];
    bool foundExceeded = false;
    bool periodsChanged = false;

    for (final period in allPeriods) {
      final progressList = await getBudgetProgress(period);
      final isExceeded = progressList.any((p) => p.percentageUsed >= 1.0);

      if (_exceededPeriods[period] != isExceeded) {
        _exceededPeriods[period] = isExceeded;
        periodsChanged = true;
      }

      if (isExceeded) {
        foundExceeded = true;
      }
    }

    if (_anyExceeded != foundExceeded || periodsChanged) {
      _anyExceeded = foundExceeded;
      notifyListeners();
    }
  }

  Future<void> checkAndNotify({String? categoryName}) async {
    // If categoryName is provided, we only check that one budget.
    // Otherwise, we check all budgets (useful for bulk updates or periodic checks).
    final budgetsToCheck = categoryName != null
        ? _budgets.where((b) => b.categoryName == categoryName).toList()
        : _budgets;

    if (budgetsToCheck.isEmpty) return;

    final DateTime now = DateTime.now();

    for (final budget in budgetsToCheck) {
      final DateTime start = _getPeriodStart(budget.period, now);

      // Calculate total spent for this category in this period
      final categorySpending = await _txRepo.getCategorySpending(start, now);
      final spendingMatch = categorySpending.firstWhere(
        (s) => s['category'] == budget.categoryName,
        orElse: () => {'total_amount': 0.0},
      );

      final double totalSpent = (spendingMatch['total_amount'] as num)
          .toDouble();
      final double percentage = totalSpent / budget.amountLimit;

      // Determine if we need to reset notification state (new period)
      int lastThreshold = budget.lastNotifiedThreshold;
      if (budget.lastNotifiedAt != null &&
          budget.lastNotifiedAt!.isBefore(start)) {
        lastThreshold = 0;
      }

      int newThreshold = lastThreshold;
      if (percentage >= 1.0 && lastThreshold < 100) {
        newThreshold = 100;
      } else if (percentage >= 0.80 && lastThreshold < 80) {
        newThreshold = 80;
      } else if (percentage >= 0.50 && lastThreshold < 50) {
        newThreshold = 50;
      }

      if (newThreshold > lastThreshold) {
        // Trigger notification
        await NotificationService.instance.showBudgetNotification(
          id: budget.id.hashCode,
          category: budget.categoryName,
          percentUsed: (percentage * 100).toInt(),
          amountLeft: (budget.amountLimit - totalSpent).clamp(
            0,
            double.infinity,
          ),
        );

        // Persist new state
        await _budgetRepo.updateNotificationState(budget.id, newThreshold, now);

        // Update local state if needed (optional since we might refresh anyway)
        final index = _budgets.indexWhere((b) => b.id == budget.id);
        if (index != -1) {
          _budgets[index] = _budgets[index].copyWith(
            lastNotifiedThreshold: newThreshold,
            lastNotifiedAt: now,
          );
        }
      }
    }
  }

  DateTime _getPeriodStart(String period, DateTime now) {
    switch (period.toLowerCase()) {
      case 'daily':
        return DateTime(now.year, now.month, now.day);
      case 'weekly':
        final int daysToSubtract = now.weekday == 7 ? 0 : now.weekday;
        final startOfCurrentWeek = now.subtract(Duration(days: daysToSubtract));
        return DateTime(
          startOfCurrentWeek.year,
          startOfCurrentWeek.month,
          startOfCurrentWeek.day,
        );
      case 'monthly':
        return DateTime(now.year, now.month, 1);
      default:
        return DateTime(now.year, now.month, now.day);
    }
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
