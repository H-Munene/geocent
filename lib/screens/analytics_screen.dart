import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/spending_service.dart';
import '../widgets/analytics/analytics_header.dart';
import '../widgets/analytics/analytics_chart.dart';
import '../widgets/analytics/analytics_legend.dart';
import '../widgets/analytics/analytics_list_tile.dart';
import '../widgets/analytics/grouped_transactions_list.dart';
import '../widgets/analytics/quick_insights_carousel.dart';
import '../widgets/analytics/analytics_selector_modal.dart';
import 'package:geocent/utils/date_periods.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _selectedSegment = 0; // 0: By Category, 1: By Recipient
  String _selectedChartType = 'Bar';

  void _showDateRangePicker(BuildContext context) {
    final spendingService = context.read<SpendingService>();

    showCupertinoModalPopup(
      context: context,
      builder: (modalContext) => AnalyticsSelectorModal(
        title: 'Select Range',
        children: [
          SelectorOption(
            label: 'This Week',
            isActive:
                spendingService.analyticsRangeMode == AnalyticsRangeMode.week,
            onTap: () {
              Navigator.pop(modalContext);
              _handleThisWeekSelection(spendingService);
            },
          ),
          SelectorOption(
            label: 'This Month',
            isActive:
                spendingService.analyticsRangeMode == AnalyticsRangeMode.month,
            onTap: () {
              Navigator.pop(modalContext);
              _handleThisMonthSelection(spendingService);
            },
          ),
          SelectorOption(
            label: 'This Year',
            isActive:
                spendingService.analyticsRangeMode == AnalyticsRangeMode.year,
            onTap: () {
              Navigator.pop(modalContext);
              _handleThisYearSelection(spendingService);
            },
          ),
          SelectorOption(
            label: 'Custom',
            isActive: false,
            onTap: () {
              Navigator.pop(modalContext);
              _showCustomRangeOptions(context, spendingService);
            },
            trailing: const Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }

  void _handleThisWeekSelection(SpendingService service) {
    final now = DateTime.now();
    final start = startOfWeek(now);
    final end = endOfWeek(now);

    service.setAnalyticsRange(
      start: start,
      end: end,
      label: null,
      mode: AnalyticsRangeMode.week,
    );
  }

  void _handleThisMonthSelection(SpendingService service) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    service.setAnalyticsRange(
      start: start,
      end: end,
      label: "${_getMonthNameFull(now.month)} ${now.year}",
      mode: AnalyticsRangeMode.month,
    );
    _ensureValidChartType(AnalyticsRangeMode.month);
  }

  void _handleThisYearSelection(SpendingService service) {
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final end = DateTime(now.year, 12, 31, 23, 59, 59);

    service.setAnalyticsRange(
      start: start,
      end: end,
      label: "${now.year}",
      mode: AnalyticsRangeMode.year,
    );
    _ensureValidChartType(AnalyticsRangeMode.year);
  }

  void _ensureValidChartType(AnalyticsRangeMode mode) {
    if ((mode == AnalyticsRangeMode.month || mode == AnalyticsRangeMode.year) &&
        _selectedChartType == 'Bar') {
      setState(() {
        _selectedChartType = 'Line';
      });
    }
  }

  void _showCustomRangeOptions(BuildContext context, SpendingService service) {
    showCupertinoModalPopup(
      context: context,
      builder: (modalContext) => AnalyticsSelectorModal(
        title: 'Custom Range',
        children: [
          SelectorOption(
            label: 'By Month',
            onTap: () {
              Navigator.pop(modalContext);
              _showMonthPicker(context, service);
            },
            trailing: const Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: CupertinoColors.systemGrey,
            ),
          ),
          SelectorOption(
            label: 'By Year',
            onTap: () {
              Navigator.pop(modalContext);
              _showYearPicker(context, service);
            },
            trailing: const Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }

  void _showMonthPicker(BuildContext context, SpendingService service) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 250,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            _buildPickerHeader(context, onDone: () => Navigator.pop(context)),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.monthYear,
                initialDateTime: DateTime.now(),
                onDateTimeChanged: (DateTime date) {
                  final start = DateTime(date.year, date.month, 1);
                  final end = DateTime(
                    date.year,
                    date.month + 1,
                    0,
                    23,
                    59,
                    59,
                  );
                  service.setAnalyticsRange(
                    start: start,
                    end: end,
                    label: "${_getMonthNameFull(date.month)} ${date.year}",
                    mode: AnalyticsRangeMode.month,
                  );
                  _ensureValidChartType(AnalyticsRangeMode.month);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showYearPicker(BuildContext context, SpendingService service) {
    final currentYear = DateTime.now().year;
    final years = List.generate(10, (index) => currentYear - index);
    int selectedYear = currentYear;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 250,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            _buildPickerHeader(
              context,
              onDone: () {
                final start = DateTime(selectedYear, 1, 1);
                final end = DateTime(selectedYear, 12, 31, 23, 59, 59);
                service.setAnalyticsRange(
                  start: start,
                  end: end,
                  label: "$selectedYear",
                  mode: AnalyticsRangeMode.year,
                );
                _ensureValidChartType(AnalyticsRangeMode.year);
                Navigator.pop(context);
              },
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 32,
                onSelectedItemChanged: (index) => selectedYear = years[index],
                children: years.map((y) => Center(child: Text("$y"))).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerHeader(
    BuildContext context, {
    required VoidCallback onDone,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: CupertinoColors.systemGrey5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onDone,
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  String _getMonthNameFull(int month) {
    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final spendingService = context.watch<SpendingService>();
    final unmappedColor = CupertinoColors.systemGrey4;

    // Dynamically build category colors map from active transactions
    final Map<String, Color> categoryColors = {};
    for (final day in spendingService.weeklyAnalytics) {
      for (final catName in day.categoryValues.keys) {
        if (!categoryColors.containsKey(catName)) {
          categoryColors[catName] = spendingService.getCategoryColor(catName);
        }
      }
    }

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: const Color(0xFFF9F9FB).withValues(alpha: 0.8),
        border: null,
        middle: Text(
          'Analytics',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      child: SafeArea(
        child: NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scrollInfo) {
            if (_selectedSegment == 1 &&
                !spendingService.isAnalyticsLoading &&
                spendingService.analyticsHasMore &&
                scrollInfo.metrics.pixels >=
                    scrollInfo.metrics.maxScrollExtent - 400) {
              spendingService.fetchAnalyticsTransactions();
            }
            return false;
          },
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 0. Quick Insights
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 16, bottom: 8),
                  child: QuickInsightsCarousel(),
                ),
              ),

              // 1. Chart Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date Selector moved from App Bar
                      Center(
                        child: GestureDetector(
                          onTap: () => _showDateRangePicker(context),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                spendingService.weekDateRange,
                                style: GoogleFonts.spaceGrotesk(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                  color: CupertinoColors.label,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                CupertinoIcons.chevron_down,
                                size: 14,
                                color: CupertinoColors.systemGrey,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      AnalyticsHeader(
                        spentThisWeek:
                            'KES ${spendingService.spentThisWeek.toInt().toString().replaceAllMapped(RegExp(r"\B(?=(\d{3})+(?!\d))"), (m) => ",")}',
                        trendPercentage:
                            '${spendingService.weeklyTrendPercentage.toInt()}%',
                        isTrendPositive: spendingService.isSpendingIncreased,
                        selectedChartType: _selectedChartType,
                        rangeMode: spendingService.analyticsRangeMode,
                        onChartTypeChanged: (type) {
                          setState(() {
                            _selectedChartType = type;
                          });
                        },
                      ),
                      const SizedBox(height: 32),
                      AnalyticsChart(
                        key: ValueKey(
                          "${spendingService.tabSwitchCount}_${spendingService.weekDateRange}_$_selectedChartType",
                        ),
                        data: spendingService.weeklyAnalytics,
                        categoryColors: categoryColors,
                        unmappedColor: unmappedColor,
                        dateRange: spendingService.weekDateRange,
                        chartType: _selectedChartType,
                      ),
                      const SizedBox(height: 24),
                      AnalyticsLegend(
                        categoryColors: categoryColors,
                        unmappedColor: unmappedColor,
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Sticky Header (Segmented Control)
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickySegmentedHeaderDelegate(
                  child: _PremiumSegmentedControl(
                    selectedValue: _selectedSegment,
                    onValueChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedSegment = value;
                        });
                      }
                    },
                  ),
                ),
              ),

              // 3. List Section
              if (_selectedSegment == 0)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item =
                            spendingService.categoryAnalyticsItems[index];
                        return AnalyticsListTile(
                          item: item,
                          categoryColor: item.category != null
                              ? spendingService.getCategoryColor(item.category!)
                              : unmappedColor,
                        );
                      },
                      childCount: spendingService.categoryAnalyticsItems.length,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  sliver: GroupedTransactionsList(
                    transactions: spendingService.analyticsTransactions,
                  ),
                ),

              // 4. Loading Indicator for Pagination
              if (_selectedSegment == 1 && spendingService.isAnalyticsLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CupertinoActivityIndicator()),
                  ),
                ),

              // Ensure the list section always fills the remaining space so the header stays pinned
              const SliverFillRemaining(
                hasScrollBody: false,
                child: SizedBox(height: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StickySegmentedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickySegmentedHeaderDelegate({required this.child});

  @override
  double get minExtent => 64.0;
  @override
  double get maxExtent => 64.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: const Color(0xFFF9F9FB),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.center,
      child: child,
    );
  }

  @override
  bool shouldRebuild(_StickySegmentedHeaderDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}

class _PremiumSegmentedControl extends StatelessWidget {
  final int selectedValue;
  final ValueChanged<int?> onValueChanged;

  const _PremiumSegmentedControl({
    required this.selectedValue,
    required this.onValueChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FB),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CupertinoSlidingSegmentedControl<int>(
        backgroundColor: CupertinoColors.systemGrey6,
        thumbColor: Colors.white,
        groupValue: selectedValue,
        children: {
          0: _buildSegment("By Category", selectedValue == 0),
          1: _buildSegment("Transactions", selectedValue == 1),
        },
        onValueChanged: onValueChanged,
      ),
    );
  }

  Widget _buildSegment(String label, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 14,
          color: isSelected ? Colors.black : CupertinoColors.systemGrey,
        ),
      ),
    );
  }
}
