import 'package:geocent/database_helper.dart';

class Budget {
  final String id;
  final String categoryName;
  final double amountLimit;
  final String period;
  final DateTime updatedAt;

  Budget({
    required this.id,
    required this.categoryName,
    required this.amountLimit,
    required this.period,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      DatabaseHelper.colId: id,
      DatabaseHelper.colCategoryName: categoryName,
      DatabaseHelper.colAmountLimit: amountLimit,
      DatabaseHelper.colPeriod: period,
      DatabaseHelper.colUpdatedAt: updatedAt.toIso8601String(),
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map[DatabaseHelper.colId] as String,
      categoryName: map[DatabaseHelper.colCategoryName] as String,
      amountLimit: (map[DatabaseHelper.colAmountLimit] as num).toDouble(),
      period: map[DatabaseHelper.colPeriod] as String,
      updatedAt: DateTime.parse(map[DatabaseHelper.colUpdatedAt] as String),
    );
  }

  Budget copyWith({
    String? id,
    String? categoryName,
    double? amountLimit,
    String? period,
    DateTime? updatedAt,
  }) {
    return Budget(
      id: id ?? this.id,
      categoryName: categoryName ?? this.categoryName,
      amountLimit: amountLimit ?? this.amountLimit,
      period: period ?? this.period,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
