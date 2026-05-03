// lib/services/spending_service.dart
import 'package:flutter/cupertino.dart';
import 'package:mapbox_tut/utils/categories.dart';
import '../models/app_transaction.dart';
import '../models/category_item.dart';
import '../repositories/transaction_repository.dart';

class SpendingService extends ChangeNotifier {
  final TransactionRepository _repo = TransactionRepository();

  // ── State ──────────────────────────────────────────────────────────────────
  double _spent = 0;
  double _limit = 0;
  String _period = 'This Week';
  List<AppTransaction> _periodTransactions = [];
  List<AppTransaction> _mappedTransactions = [];
  List<AppTransaction> _actionableTransactions = [];
  String? _selectedTxId;
  bool _isLoading = false;

  // default icons that are more likely to be used. I know this implementation
  // is not robust but whatever man
  final List<CategoryItem> _defaultCategories = [
    availableIcons[2]!, // dining
    availableIcons[29]!, // snacks
    availableIcons[35]!, // public transport
    availableIcons[1]!, // shopping
    availableIcons[6]!, // taxi
    availableIcons[37]!, // social
    availableIcons[10]!, // entertainment
    availableIcons[17]!, // laundry
    availableIcons[24]!, // household utilities
    availableIcons[23]!, // phone bill
    availableIcons[26]!, // subscription
    availableIcons[25]!, // savings
    availableIcons[7]!, // health
    availableIcons[5]!, // services
    availableIcons[43]!, // hobby
    availableIcons[4]!, // pet
  ];

  // ── Getters ────────────────────────────────────────────────────────────────
  double get spent => _spent;
  double get limit => _limit;
  String get period => _period;
  bool get isLoading => _isLoading;
  List<AppTransaction> get periodTransactions => _periodTransactions;
  List<CategoryItem> get categories => List.unmodifiable(_defaultCategories);

  /// Only transactions with GPS — used to rebuild map annotations.
  List<AppTransaction> get mappedTransactions => _mappedTransactions;

  /// Transactions that need mapping or categorization.
  List<AppTransaction> get actionableTransactions => _actionableTransactions;

  /// The transaction ID selected from the Messages screen to be categorized on the Map.
  String? get selectedTxId => _selectedTxId;

  CategoryItem? getCategoryByName(String? name) {
    if (name == null) return null;
    try {
      return _defaultCategories.firstWhere((c) => c.name == name);
    } catch (_) {
      return null;
    }
  }

  /// 0.0 → 1.0, clamped so the UI never breaks at >100 %.
  double get progress => _limit > 0 ? (_spent / _limit).clamp(0.0, 1.0) : 0.0;

  double get remaining => (_limit - _spent).clamp(0.0, double.infinity);

  /// Colour signal for DynamicIsland progress indicators.
  /// blue < 75 % → amber 75–90 % → red > 90 %
  ProgressLevel get progressLevel {
    if (progress >= 0.90) return ProgressLevel.danger;
    if (progress >= 0.75) return ProgressLevel.warning;
    return ProgressLevel.safe;
  }

  // ── Init ───────────────────────────────────────────────────────────────────

  /// Call once from home.dart initState (or in the provider's create callback).
  Future<void> init() async {
    await refresh();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Set the selected transaction and notify listeners to trigger navigation/popups.
  void selectTransaction(String id) {
    _selectedTxId = id;
    notifyListeners();
  }

  /// Clear the selected transaction after it has been handled.
  void clearSelectedTransaction() {
    _selectedTxId = null;
    notifyListeners();
  }

  /// Switch period and reload — called by DynamicIsland onPeriodSelected.
  Future<void> setPeriod(String period) async {
    _period = period;
    await refresh();
  }

  /// Reload spent totals, limit, and mapped transactions from DB.
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    // Map DynamicIsland period labels → DB period keys
    final String dbPeriod = _toDbPeriod(_period);

    final results = await Future.wait([
      _repo.loadByPeriod(_period),
      _repo.loadMapped(),
      _repo.getLimit(dbPeriod),
      _repo.loadActionable(),
    ]);

    _periodTransactions = results[0] as List<AppTransaction>;
    _mappedTransactions = results[1] as List<AppTransaction>;
    _limit = results[2] as double;
    _actionableTransactions = results[3] as List<AppTransaction>;
    _spent = _periodTransactions.fold(0.0, (sum, tx) => sum + tx.amount);

    _isLoading = false;
    notifyListeners();
  }

  /// Save a freshly-parsed transaction then refresh totals.
  Future<void> addTransaction(AppTransaction tx) async {
    await _repo.save(tx);
    await refresh();
  }

  /// Attach GPS to an existing transaction then refresh the map layer.
  Future<void> attachLocation(
    String txId,
    double latitude,
    double longitude,
  ) async {
    await _repo.updateLocation(txId, latitude, longitude);
    // Refresh to ensure all lists (mapped, actionable) are updated and listeners notified
    await refresh();
  }

  /// Update the category of an existing transaction then refresh state.
  Future<void> updateCategory(String txId, String category) async {
    await _repo.updateCategory(txId, category);
    // Refresh to update UI with new category and remove from actionable if complete
    await refresh();
  }

  /// Persist a new limit for the current period then refresh.
  Future<void> setLimit(String period, double amount) async {
    await _repo.setLimit(_toDbPeriod(period), amount);
    if (period == _period) {
      _limit = amount;
      notifyListeners();
    }
  }

  void addCategory(CategoryItem category) {
    if (!_defaultCategories.any((c) => c.name == category.name)) {
      _defaultCategories.add(category);
      notifyListeners();
    }
  }

  /// Convenience: returns all three limits for the settings screen.
  Future<Map<String, double>> getAllLimits() => _repo.getAllLimits();

  // ── Private ────────────────────────────────────────────────────────────────

  /// Maps DynamicIsland display strings to the DB period keys.
  String _toDbPeriod(String displayPeriod) {
    switch (displayPeriod) {
      case 'Today':
        return 'daily';
      case 'This Week':
        return 'weekly';
      case 'Month':
        return 'monthly';
      default:
        return 'weekly';
    }
  }
}

enum ProgressLevel { safe, warning, danger }
