enum TransactionSource { mpesa, equity }

enum TransactionType { sent, payment, received, unknown }

class AppTransaction {
  final String id; // M-PESA code e.g. UDQ0H234DB / Equity ref e.g. 611602020521
  final double amount;
  final String merchant; // recipient name or merchant
  final String rawMessage;
  final DateTime timestamp;
  final double? balanceAfter;
  final TransactionSource source;
  final TransactionType type;
  final double? latitude;
  final double? longitude;
  final String? category;

  const AppTransaction({
    required this.id,
    required this.amount,
    required this.merchant,
    required this.rawMessage,
    required this.timestamp,
    required this.source,
    required this.type,
    this.balanceAfter,
    this.latitude,
    this.longitude,
    this.category,
  });

  // ── Persistence ────────────────────────────────────────────────────────────

  /// Serialise to a map whose keys match DatabaseHelper column constants.
  Map<String, dynamic> toMap() => {
    'id': id,
    'amount': amount,
    'merchant': merchant,
    'raw_message': rawMessage,
    'timestamp': timestamp.toIso8601String(),
    'balance_after': balanceAfter,
    'source': source.name, // 'mpesa' | 'equity'
    'type': type.name, // 'sent' | 'payment' | 'received' | 'unknown'
    'latitude': latitude,
    'longitude': longitude,
    'category': category,
  };

  factory AppTransaction.fromMap(Map<String, dynamic> map) => AppTransaction(
    id: map['id'] as String,
    amount: (map['amount'] as num).toDouble(),
    merchant: map['merchant'] as String,
    rawMessage: map['raw_message'] as String,
    timestamp: DateTime.parse(map['timestamp'] as String),
    balanceAfter: map['balance_after'] != null
        ? (map['balance_after'] as num).toDouble()
        : null,
    source: TransactionSource.values.byName(map['source'] as String),
    type: TransactionType.values.byName(map['type'] as String),
    latitude: map['latitude'] != null
        ? (map['latitude'] as num).toDouble()
        : null,
    longitude: map['longitude'] != null
        ? (map['longitude'] as num).toDouble()
        : null,
    category: map['category'] as String?,
  );

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool get hasLocation => latitude != null && longitude != null;

  /// e.g. "Ksh 1,450"
  String get formattedAmount =>
      'Ksh ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}';

  /// Returns a copy with coordinates attached (used after GPS resolves).
  AppTransaction withLocation(double lat, double lng) => AppTransaction(
    id: id,
    amount: amount,
    merchant: merchant,
    rawMessage: rawMessage,
    timestamp: timestamp,
    balanceAfter: balanceAfter,
    source: source,
    type: type,
    latitude: lat,
    longitude: lng,
    category: category,
  );
}
