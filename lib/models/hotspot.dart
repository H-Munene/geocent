class Hotspot {
  final String id;
  final String stableKey;
  final double latitude;
  final double longitude;
  final double radius;
  final double avgSpend;
  final double totalSpend;
  final int transactionCount;
  final DateTime? lastNotifiedAt;

  Hotspot({
    required this.id,
    required this.stableKey,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.avgSpend,
    required this.totalSpend,
    required this.transactionCount,
    this.lastNotifiedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'stable_key': stableKey,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'avg_spend': avgSpend,
      'total_spend': totalSpend,
      'transaction_count': transactionCount,
      'last_notified_at': lastNotifiedAt?.toIso8601String(),
    };
  }

  factory Hotspot.fromMap(Map<String, dynamic> map) {
    return Hotspot(
      id: map['id'] as String,
      stableKey: map['stable_key'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      radius: (map['radius'] as num).toDouble(),
      avgSpend: (map['avg_spend'] as num).toDouble(),
      totalSpend: (map['total_spend'] as num).toDouble(),
      transactionCount: map['transaction_count'] as int,
      lastNotifiedAt: map['last_notified_at'] != null
          ? DateTime.parse(map['last_notified_at'] as String)
          : null,
    );
  }

  Hotspot copyWith({
    String? id,
    String? stableKey,
    double? latitude,
    double? longitude,
    double? radius,
    double? avgSpend,
    double? totalSpend,
    int? transactionCount,
    DateTime? lastNotifiedAt,
  }) {
    return Hotspot(
      id: id ?? this.id,
      stableKey: stableKey ?? this.stableKey,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radius: radius ?? this.radius,
      avgSpend: avgSpend ?? this.avgSpend,
      totalSpend: totalSpend ?? this.totalSpend,
      transactionCount: transactionCount ?? this.transactionCount,
      lastNotifiedAt: lastNotifiedAt ?? this.lastNotifiedAt,
    );
  }
}
