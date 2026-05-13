import 'package:flutter/cupertino.dart';

class QuickInsightPrimary {
  final String label;
  final double amount;

  QuickInsightPrimary({required this.label, required this.amount});
}

class QuickInsightCategory {
  final String categoryName;
  final double amount;
  final Color color;
  final dynamic icon;
  final String period;

  QuickInsightCategory({
    required this.categoryName,
    required this.amount,
    required this.color,
    required this.icon,
    required this.period,
  });
}

class QuickInsightTrend {
  final String periodLabel;
  final String comparisonLabel;
  final double amountDifference;
  final bool isMore;

  QuickInsightTrend({
    required this.periodLabel,
    required this.comparisonLabel,
    required this.amountDifference,
    required this.isMore,
  });
}

class QuickInsightMonthly {
  final String monthName;
  final double amount;

  QuickInsightMonthly({required this.monthName, required this.amount});
}

class QuickInsightsData {
  final List<QuickInsightPrimary> primary;
  final List<QuickInsightCategory> topCategories;
  final List<QuickInsightTrend> trends;
  final List<QuickInsightMonthly> monthly;

  QuickInsightsData({
    required this.primary,
    required this.topCategories,
    required this.trends,
    required this.monthly,
  });

  factory QuickInsightsData.empty() => QuickInsightsData(
    primary: [],
    topCategories: [],
    trends: [],
    monthly: [],
  );
}
