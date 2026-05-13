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
  final IconData icon;

  QuickInsightCategory({
    required this.categoryName,
    required this.amount,
    required this.color,
    required this.icon,
  });
}

class QuickInsightCounts {
  final String period;
  final int mapped;
  final int categorized;

  QuickInsightCounts({
    required this.period,
    required this.mapped,
    required this.categorized,
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
  final List<QuickInsightCounts> counts;
  final List<QuickInsightMonthly> monthly;

  QuickInsightsData({
    required this.primary,
    required this.topCategories,
    required this.counts,
    required this.monthly,
  });

  factory QuickInsightsData.empty() => QuickInsightsData(
    primary: [],
    topCategories: [],
    counts: [],
    monthly: [],
  );
}
