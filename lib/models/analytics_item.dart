class AnalyticsItem {
  final String title;
  final int count;
  final double total;
  final double? trend; // Current week total - Previous week total
  final String? category;
  final String? initials;

  AnalyticsItem({
    required this.title,
    required this.count,
    required this.total,
    this.trend,
    this.category,
    this.initials,
  });

  bool get isTrendPositive => (trend ?? 0) > 0;
  bool get isTrendNegative => (trend ?? 0) < 0;
}
