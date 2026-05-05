class CategoryAnalytics {
  final String category;
  final double todayTotal;
  final double yesterdayTotal;

  CategoryAnalytics({
    required this.category,
    required this.todayTotal,
    required this.yesterdayTotal,
  });

  double get difference => todayTotal - yesterdayTotal;

  bool get isNegative => difference < 0;
  bool get isPositive => difference > 0;

  String get trimmedCategory {
    if (category.length <= 8) return category;
    return '${category.substring(0, 8)}...';
  }

  String get formattedDifference {
    final absDiff = difference.abs();
    final sign = difference >= 0 ? '+' : '-';
    final formatted = absDiff
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    return ' $sign KES $formatted';
  }
}
