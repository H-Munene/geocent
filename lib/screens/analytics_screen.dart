import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/spending_service.dart';
import '../widgets/analytics/analytics_header.dart';
import '../widgets/analytics/analytics_chart.dart';
import '../widgets/analytics/analytics_legend.dart';
import '../widgets/analytics/analytics_list_tile.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _selectedSegment = 0; // 0: By Category, 1: By Recipient

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

    final listItems = _selectedSegment == 0
        ? spendingService.categoryAnalyticsItems
        : spendingService.recipientAnalyticsItems;

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: const Color(0xFFF9F9FB).withValues(alpha: 0.8),
        border: null,
        middle: Text(
          spendingService.weekDateRange,
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 1. Chart Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnalyticsHeader(
                      dailyAverage:
                          'KES ${spendingService.dailyAverage.toInt().toString().replaceAllMapped(RegExp(r"\B(?=(\d{3})+(?!\d))"), (m) => ",")}',
                      trendPercentage:
                          '${spendingService.weeklyTrendPercentage.toInt()}%',
                      isTrendPositive: spendingService.isSpendingIncreased,
                    ),
                    const SizedBox(height: 32),
                    AnalyticsChart(
                      key: ValueKey(spendingService.tabSwitchCount),
                      data: spendingService.weeklyAnalytics,
                      categoryColors: categoryColors,
                      unmappedColor: unmappedColor,
                      dateRange: spendingService.weekDateRange,
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
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = listItems[index];
                  return AnalyticsListTile(
                    item: item,
                    categoryColor: item.category != null
                        ? spendingService.getCategoryColor(item.category!)
                        : unmappedColor,
                  );
                }, childCount: listItems.length),
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
          1: _buildSegment("By Recipient", selectedValue == 1),
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
