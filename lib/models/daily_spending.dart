class DailySpending {
  final DateTime date;
  final String dayName;
  final bool isToday;
  final Map<String, double> categoryValues;
  final double unmappedValue;

  DailySpending({
    required this.date,
    required this.dayName,
    this.isToday = false,
    required this.categoryValues,
    this.unmappedValue = 0,
  });

  double get total =>
      categoryValues.values.fold(0.0, (a, b) => a + b) + unmappedValue;
}
