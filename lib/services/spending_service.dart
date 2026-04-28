// lib/services/spending_service.dart
import 'package:flutter/foundation.dart';
import '../models/app_transaction.dart';
import '../repositories/transaction_repository.dart';

class SpendingService extends ChangeNotifier {
  final TransactionRepository _repo = TransactionRepository();

  // ── State ──────────────────────────────────────────────────────────────────
  double _spent = 0;
  double _limit = 0;
  String _period = 'This Week';
  List<AppTransaction> _periodTransactions = [];
  List<AppTransaction> _mappedTransactions = [];
  bool _isLoading = false;

  // ── Getters ────────────────────────────────────────────────────────────────
  double get spent => _spent;
  double get limit => _limit;
  String get period => _period;
  bool get isLoading => _isLoading;
  List<AppTransaction> get periodTransactions => _periodTransactions;

  /// Only transactions with GPS — used to rebuild map annotations.
  List<AppTransaction> get mappedTransactions => _mappedTransactions;

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
    ]);

    _periodTransactions = results[0] as List<AppTransaction>;
    _mappedTransactions = results[1] as List<AppTransaction>;
    _limit = results[2] as double;
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
    // Only reload the mapped list — no need to recompute totals
    _mappedTransactions = await _repo.loadMapped();
    notifyListeners();
  }

  /// Persist a new limit for the current period then refresh.
  Future<void> setLimit(String period, double amount) async {
    await _repo.setLimit(_toDbPeriod(period), amount);
    if (period == _period) {
      _limit = amount;
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
