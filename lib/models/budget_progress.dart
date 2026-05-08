import 'package:geocent/models/budget.dart';

class BudgetProgress {
  final String categoryName;
  final double amountLimit;
  final double totalSpentInPeriod;
  final double percentageUsed;
  final Budget budget;

  BudgetProgress({
    required this.categoryName,
    required this.amountLimit,
    required this.totalSpentInPeriod,
    required this.percentageUsed,
    required this.budget,
  });
}
