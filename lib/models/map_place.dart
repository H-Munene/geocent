import 'app_transaction.dart';

class MapPlace {
  final String id;
  final String name;
  final String price;
  final double latitude;
  final double longitude;
  final String rawMessage;
  final String? category;

  const MapPlace({
    required this.id,
    required this.name,
    required this.price,
    required this.latitude,
    required this.longitude,
    required this.rawMessage,
    this.category,
  });

  AppTransaction toTransaction() {
    return AppTransaction(
      id: id,
      merchant: name,
      amount: double.tryParse(price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0,
      timestamp: DateTime.now(),
      rawMessage: rawMessage,
      latitude: latitude,
      longitude: longitude,
      category: category,
      source: TransactionSource.mpesa,
      type: TransactionType.unknown,
    );
  }
}
