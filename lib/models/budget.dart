import 'package:geocent/database_helper.dart';

class Budget {
  final String id;
  final String categoryName;
  final double amountLimit;
  final String period;
  final DateTime updatedAt;
  final int lastNotifiedThreshold;
  final DateTime? lastNotifiedAt;

  Budget({
    required this.id,
    required this.categoryName,
    required this.amountLimit,
    required this.period,
    required this.updatedAt,
    this.lastNotifiedThreshold = 0,
    this.lastNotifiedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      DatabaseHelper.colId: id,
      DatabaseHelper.colCategoryName: categoryName,
      DatabaseHelper.colAmountLimit: amountLimit,
      DatabaseHelper.colPeriod: period,
      DatabaseHelper.colUpdatedAt: updatedAt.toIso8601String(),
      DatabaseHelper.colLastNotifiedThreshold: lastNotifiedThreshold,
      DatabaseHelper.colLastNotifiedAt: lastNotifiedAt?.toIso8601String(),
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map[DatabaseHelper.colId] as String,
      categoryName: map[DatabaseHelper.colCategoryName] as String,
      amountLimit: (map[DatabaseHelper.colAmountLimit] as num).toDouble(),
      period: map[DatabaseHelper.colPeriod] as String,
      updatedAt: DateTime.parse(map[DatabaseHelper.colUpdatedAt] as String),
      lastNotifiedThreshold:
          map[DatabaseHelper.colLastNotifiedThreshold] as int? ?? 0,
      lastNotifiedAt: map[DatabaseHelper.colLastNotifiedAt] != null
          ? DateTime.parse(map[DatabaseHelper.colLastNotifiedAt] as String)
          : null,
    );
  }

  Budget copyWith({
    String? id,
    String? categoryName,
    double? amountLimit,
    String? period,
    DateTime? updatedAt,
    int? lastNotifiedThreshold,
    DateTime? lastNotifiedAt,
  }) {
    return Budget(
      id: id ?? this.id,
      categoryName: categoryName ?? this.categoryName,
      amountLimit: amountLimit ?? this.amountLimit,
      period: period ?? this.period,
      updatedAt: updatedAt ?? this.updatedAt,
      lastNotifiedThreshold:
          lastNotifiedThreshold ?? this.lastNotifiedThreshold,
      lastNotifiedAt: lastNotifiedAt ?? this.lastNotifiedAt,
    );
  }
}
