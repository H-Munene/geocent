import 'app_transaction.dart';

class MapPlace {
  final String name; // Merchant name (all in group should have same merchant)
  final double latitude;
  final double longitude;
  final List<AppTransaction> transactions;

  const MapPlace({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.transactions,
  });

  String get id => transactions.first.id;
  String? get category => transactions.first.category;
  String get displayPrice => transactions.length > 1
      ? '+${transactions.length - 1} more'
      : transactions.first.formattedAmount;

  double get totalAmount =>
      transactions.fold(0.0, (sum, tx) => sum + tx.amount);

  AppTransaction toTransaction() {
    return transactions.first;
  }
}
