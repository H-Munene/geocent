import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../services/spending_service.dart';
import '../widgets/analytics/analytics_header.dart';
import '../widgets/analytics/analytics_chart.dart';
import '../widgets/analytics/analytics_legend.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final spendingService = context.watch<SpendingService>();
    final unmappedColor = CupertinoColors.systemGrey4;

    // Dynamically build category colors map from active transactions
    final Map<String, Color> categoryColors = {};
    for (final day in spendingService.weeklyAnalytics) {
      for (final catName in day.categoryValues.keys) {
        if (!categoryColors.containsKey(catName)) {
          final catItem = spendingService.getCategoryByName(catName);
          categoryColors[catName] =
              catItem?.color ?? CupertinoColors.systemGrey2;
        }
      }
    }

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: const Color(0xFFF9F9FB).withValues(alpha: 0.8),
        border: null,
        middle: const Text(
          'Analytics',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnalyticsHeader(
                dailyAverage: 'KES ${spendingService.dailyAverage.toInt()}',
                trendPercentage:
                    '${spendingService.weeklyTrendPercentage.toInt()}%',
                isTrendPositive: spendingService.isSpendingIncreased,
              ),
              const SizedBox(height: 32),
              AnalyticsChart(
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
    );
  }
}
