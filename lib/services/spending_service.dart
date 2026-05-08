// lib/services/spending_service.dart
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:geocent/models/category_analytics.dart';
import 'package:geocent/utils/categories.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_transaction.dart';
import '../models/category_item.dart';
import '../models/daily_spending.dart';
import '../repositories/transaction_repository.dart';

class SpendingService extends ChangeNotifier {
  final TransactionRepository _repo = TransactionRepository();

  // ── State ──────────────────────────────────────────────────────────────────
  double _spent = 0;
  double _limit = 0;
  String _period = 'This Week';
  List<AppTransaction> _periodTransactions = [];
  List<AppTransaction> _mappedTransactions = [];
  List<CategoryAnalytics> _categoryComparison = [];
  final List<AppTransaction> _actionableTransactions = [];
  String? _selectedTxId;
  bool _isLoading = false;
  List<AppTransaction> _allTransactions = [];

  // Analytics State
  List<DailySpending> _weeklyAnalytics = [];
  double _weeklyTrendPercentage = 0;
  bool _isSpendingIncreased = false;
  double _dailyAverage = 0;
  String _weekDateRange = '';

  // Pagination & Filtering state
  List<AppTransaction> _paginatedMessages = [];
  String _currentFilter = 'all';
  String _searchQuery = ''; // Add this
  int _currentPage = 0;
  bool _hasMore = true;
  final int _pageSize = 20;

  // Merchant category cache for performance
  final Map<String, String> _merchantCategoryCache = {};

  // Category Colors Map
  final Map<String, Color> _categoryColors = {
    'Dining': CupertinoColors.systemOrange,
    'Snacks': const Color(0xFFFFCC00),
    'Public Transport': CupertinoColors.systemBrown,
    'Shopping': CupertinoColors.systemTeal,
    'Taxi': CupertinoColors.black,
    'Social': const Color.fromARGB(183, 243, 3, 211),
    'Entertainment': const Color.fromARGB(137, 2, 139, 157),
    'Laundry': const Color(0xFFE2D746),
    'Household Utilities': const Color(0xFF0A84FF),
    'Phone Bill': const Color(0xFF36EA84),
    'Subscriptions': const Color.fromARGB(255, 182, 67, 94),
    'Savings': const Color.fromARGB(255, 186, 195, 58),
    'Health': CupertinoColors.systemRed,
    'Services': const Color(0xFF0EAFE2),
    'Hobby': CupertinoColors.systemIndigo,
    'Pet': CupertinoColors.systemMint,
  };

  // A set of frequently used default categories.
  // This list provides immediate actionable options for the user.
  final List<CategoryItem> _defaultCategories = [
    availableIcons[2]!, // dining
    availableIcons[29]!, // snacks
    availableIcons[35]!, // public transport
    availableIcons[1]!, // shopping
    availableIcons[34]!, // taxi
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
  List<CategoryAnalytics> get categoryComparison => _categoryComparison;
  List<CategoryItem> get categories => List.unmodifiable(_defaultCategories);

  /// Only transactions with GPS — used to rebuild map annotations.
  List<AppTransaction> get mappedTransactions => _mappedTransactions;

  /// Transactions that need mapping or categorization.
  List<AppTransaction> get actionableTransactions => _actionableTransactions;

  List<AppTransaction> get paginatedMessages => _paginatedMessages;
  String get currentFilter => _currentFilter;
  bool get hasMore => _hasMore;
  List<AppTransaction> get allTransactions => _allTransactions; // New getter
  String get searchQuery => _searchQuery;

  /// The transaction ID selected from the Messages screen to be categorized on the Map.
  String? get selectedTxId => _selectedTxId;

  // Analytics Getters
  List<DailySpending> get weeklyAnalytics => _weeklyAnalytics;
  double get weeklyTrendPercentage => _weeklyTrendPercentage;
  bool get isSpendingIncreased => _isSpendingIncreased;
  double get dailyAverage => _dailyAverage;
  String get weekDateRange => _weekDateRange;

  Color getCategoryColor(String name) {
    return _categoryColors[name] ?? CupertinoColors.systemGrey2;
  }

  /// Returns icons that are not yet assigned to any category.
  List<CategoryItem> get availableIconsPool {
    final usedIcons = _defaultCategories.map((c) => c.icon).toSet();
    return availableIcons.values
        .where((icon) => !usedIcons.contains(icon.icon))
        .toList();
  }

  CategoryItem? getCategoryByName(String? name) {
    if (name == null) return null;
    // Check in-memory actively used categories first (includes custom ones)
    final fromMemory = _defaultCategories
        .where((c) => c.name == name)
        .firstOrNull;
    if (fromMemory != null) return fromMemory;
    // Fallback to all available icons
    return availableIcons.values.where((c) => c.name == name).firstOrNull;
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
    await _loadCustomCategories();
    await refresh();
  }

  // ── Custom Categories Persistence ──────────────────────────────────────────

  Future<void> _loadCustomCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customCatsStr = prefs.getString('custom_categories');
      if (customCatsStr != null) {
        final List<dynamic> decoded = jsonDecode(customCatsStr);
        for (final item in decoded) {
          final String name = item['name'];
          final int baseId = item['baseId'];
          final int colorValue = item['colorValue'];

          if (availableIcons.containsKey(baseId) &&
              !_defaultCategories.any((c) => c.name == name)) {
            final baseCat = availableIcons[baseId]!;
            _defaultCategories.add(
              CategoryItem(name: name, icon: baseCat.icon),
            );
            _categoryColors[name] = Color(colorValue);
          }
        }
      }
    } catch (e) {
      debugPrint('[SpendingService] Failed to load custom categories: $e');
    }
  }

  Future<void> _saveCustomCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Filter out the built-in default ones to only save custom ones
      final builtInNames = availableIcons.values.map((c) => c.name).toSet();
      final customCategories = _defaultCategories
          .where((c) => !builtInNames.contains(c.name))
          .toList();

      final List<Map<String, dynamic>> toSave = customCategories.map((cat) {
        // Find baseId
        int baseId = 2; // Default to dining
        for (final entry in availableIcons.entries) {
          if (entry.value.icon == cat.icon) {
            baseId = entry.key;
            break;
          }
        }
        return {
          'name': cat.name,
          'baseId': baseId,
          'colorValue': getCategoryColor(cat.name).toARGB32(),
        };
      }).toList();

      await prefs.setString('custom_categories', jsonEncode(toSave));
    } catch (e) {
      debugPrint('[SpendingService] Failed to save custom categories: $e');
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Clears the search query and resets the current filter to 'all'.
  void resetSearchAndFilters() {
    _searchQuery = '';
    _currentFilter = 'all';
    _currentPage = 0;
    _hasMore = true;
    _paginatedMessages = [];
    notifyListeners();
    // Re-fetch messages so that screens are populated with fresh data
    fetchMessages(refresh: true);
  }

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

  Future<List<AppTransaction>> searchMessages(String query) async {
    if (query.isEmpty) return [];
    return await _repo.searchTransactions(query);
  }

  Future<List<AppTransaction>> getMessagesByCategory(String category) async {
    return await _repo.loadByCategory(category);
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
      _repo.getCategoryComparison(),
      _updateAnalytics(), // Added this
    ]);

    _periodTransactions = results[0] as List<AppTransaction>;
    _mappedTransactions = results[1] as List<AppTransaction>;
    _limit = results[2] as double;
    _categoryComparison = results[3] as List<CategoryAnalytics>;
    _spent = _periodTransactions.fold(0.0, (sum, tx) => sum + tx.amount);
    _allTransactions = await _repo.loadAll(); // Load all transactions

    _isLoading = false;
    notifyListeners();

    // Also refresh paginated messages to keep them in sync
    await fetchMessages(refresh: true);
  }

  /// Calculates weekly analytics including daily breakdown, trends, and averages.
  Future<void> _updateAnalytics() async {
    final now = DateTime.now();
    // Sunday of the current week (local time)
    // Dart's weekday: 1 = Mon, 7 = Sun. To start on Sun, subtract weekday % 7.
    final int daysToSubtract = now.weekday == 7 ? 0 : now.weekday;
    final startOfCurrentWeek = now.subtract(Duration(days: daysToSubtract));
    final currentWeekStart = DateTime(
      startOfCurrentWeek.year,
      startOfCurrentWeek.month,
      startOfCurrentWeek.day,
    );

    // Previous week boundaries
    final previousWeekStart = currentWeekStart.subtract(
      const Duration(days: 7),
    );
    final previousWeekEnd = currentWeekStart.subtract(
      const Duration(milliseconds: 1),
    );

    // Date range string for UI (e.g., "3 May – 9 May")
    final endOfWeek = currentWeekStart.add(const Duration(days: 6));
    final months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    _weekDateRange =
        "${currentWeekStart.day} ${months[currentWeekStart.month - 1]} – ${endOfWeek.day} ${months[endOfWeek.month - 1]}";

    final results = await Future.wait([
      _repo.getDailySpendingByCategory(currentWeekStart, now),
      _repo.getTotalSpending(previousWeekStart, previousWeekEnd),
    ]);

    final List<Map<String, dynamic>> dailyRaw =
        results[0] as List<Map<String, dynamic>>;
    final double previousTotal = results[1] as double;

    // 1. Build the 7-day breakdown (Sunday to Saturday)
    final List<DailySpending> weekly = [];
    final List<String> dayNames = [
      "Sun",
      "Mon",
      "Tue",
      "Wed",
      "Thu",
      "Fri",
      "Sat",
    ];
    double totalMappedThisWeek = 0;

    for (int i = 0; i < 7; i++) {
      final date = currentWeekStart.add(Duration(days: i));
      final dateStr =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

      final dayEntries = dailyRaw.where((r) => r['day'] == dateStr).toList();
      final Map<String, double> categories = {};
      double unmapped = 0;

      for (final entry in dayEntries) {
        final category = entry['category'] as String?;
        final amount = (entry['total_amount'] as num).toDouble();
        if (category == null) {
          unmapped += amount;
        } else {
          categories[category] = amount;
          totalMappedThisWeek += amount;
        }
      }

      weekly.add(
        DailySpending(
          date: date,
          dayName: date.day == now.day && date.month == now.month
              ? "Today"
              : dayNames[i],
          isToday: date.day == now.day && date.month == now.month,
          categoryValues: categories,
          unmappedValue: unmapped,
        ),
      );
    }

    _weeklyAnalytics = weekly;

    // 2. Trend Calculation
    final double currentTotal = dailyRaw.fold(
      0.0,
      (sum, r) => sum + (r['total_amount'] as num).toDouble(),
    );
    if (previousTotal == 0) {
      _weeklyTrendPercentage = currentTotal > 0 ? 100 : 0;
    } else {
      _weeklyTrendPercentage =
          ((currentTotal - previousTotal) / previousTotal * 100).abs();
    }
    _isSpendingIncreased = currentTotal > previousTotal;

    // 3. Daily Average (Total mapped spending / days elapsed)
    final int daysElapsed = now.difference(currentWeekStart).inDays + 1;
    _dailyAverage = totalMappedThisWeek / daysElapsed;
  }

  /// Save a freshly-parsed transaction then refresh totals.
  Future<void> addTransaction(AppTransaction tx) async {
    // Auto-categorize based on merchant history
    if (tx.category == null) {
      String? cachedCategory = _merchantCategoryCache[tx.merchant];
      if (cachedCategory == null) {
        cachedCategory = await _repo.getMerchantCategory(tx.merchant);
        if (cachedCategory != null) {
          _merchantCategoryCache[tx.merchant] = cachedCategory;
        }
      }

      if (cachedCategory != null) {
        tx = tx.copyWith(category: cachedCategory);
      }
    }

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

    // Learn and persist merchant preference
    final tx = [
      ..._periodTransactions,
      ..._paginatedMessages,
    ].where((t) => t.id == txId).firstOrNull;
    if (tx != null) {
      _merchantCategoryCache[tx.merchant] = category;
      await _repo.upsertMerchantCategory(tx.merchant, category);
    }

    // Refresh to update UI with new category and remove from actionable if complete
    await refresh();
  }

  Future<void> bulkUpdateCategory(List<String> ids, String category) async {
    await _repo.updateCategories(ids, category);

    // Learn and persist merchant preferences for all unique merchants in the batch
    final affectedTxs = _paginatedMessages
        .where((t) => ids.contains(t.id))
        .toList();
    final uniqueMerchants = affectedTxs.map((t) => t.merchant).toSet();

    for (final merchant in uniqueMerchants) {
      _merchantCategoryCache[merchant] = category;
      await _repo.upsertMerchantCategory(merchant, category);
    }

    await refresh();
    await fetchMessages(refresh: true);
  }

  /// Persist a new limit for the current period then refresh.
  Future<void> setLimit(String period, double amount) async {
    await _repo.setLimit(_toDbPeriod(period), amount);
    if (period == _period) {
      _limit = amount;
      notifyListeners();
    }
  }

  Future<void> setFilter(String filter) async {
    if (_currentFilter == filter) return;
    _currentFilter = filter;
    _currentPage = 0;
    _paginatedMessages = [];
    _hasMore = true;
    // Pass the current search query when setting a new filter
    await fetchMessages(refresh: true, searchQuery: _searchQuery);
  }

  Future<void> fetchMessages({
    bool refresh = false,
    String? searchQuery,
  }) async {
    if (_isLoading) return;
    if (!refresh && !_hasMore) return;

    _isLoading = true;
    notifyListeners();

    if (refresh) {
      _currentPage = 0;
      _paginatedMessages = [];
      _hasMore = true;
    }

    if (searchQuery != null) {
      _searchQuery = searchQuery;
    }

    try {
      final newMessages = await _repo.loadFiltered(
        filter: _currentFilter,
        limit: _pageSize,
        offset: _currentPage * _pageSize,
        searchQuery: _searchQuery, // Pass the search query
      );

      if (newMessages.length < _pageSize) {
        _hasMore = false;
      }

      _paginatedMessages.addAll(newMessages);
      _currentPage++;
    } catch (e) {
      debugPrint('[SpendingService] Failed to fetch messages: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void addCategory(CategoryItem category, Color color) {
    if (!_defaultCategories.any((c) => c.name == category.name)) {
      _defaultCategories.add(category);
      _categoryColors[category.name] = color;
      _saveCustomCategories();
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
