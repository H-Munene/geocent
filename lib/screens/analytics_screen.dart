import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import '../services/spending_service.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  String _formatKsh(double val) =>
      'Ksh ${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}';

  @override
  Widget build(BuildContext context) {
    final spending = context.watch<SpendingService>();
    final transactions = spending.periodTransactions;

    // Group transactions by category
    final Map<String, double> categoryTotals = {};
    for (var tx in transactions) {
      final String catName = tx.category ?? 'Uncategorized';
      categoryTotals[catName] = (categoryTotals[catName] ?? 0.0) + tx.amount;
    }

    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Colors.white.withValues(alpha: 0.8),
        border: null,
        middle: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Text(
              'Analytics',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: const Color(0xFF1D1D1F),
              ),
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildHeroCard(spending),
            const SizedBox(height: 32),
            _buildSectionHeader('Spend Distribution'),
            const SizedBox(height: 16),
            if (sortedCategories.isNotEmpty)
              _buildDistributionChart(sortedCategories, spending.spent),
            const SizedBox(height: 32),
            _buildSectionHeader('Category Breakdown'),
            const SizedBox(height: 12),
            if (sortedCategories.isEmpty)
              _buildEmptyState()
            else
              ...sortedCategories.map(
                (entry) => _buildCategoryTile(context, entry, spending.spent),
              ),
            const SizedBox(height: 32),
            _buildSectionHeader('Insights'),
            const SizedBox(height: 12),
            _buildInsightCard(
              'Daily Average',
              _formatKsh(
                spending.spent /
                    (spending.period == 'Today'
                        ? 1
                        : (spending.period == 'This Week' ? 7 : 30)),
              ),
              CupertinoIcons.graph_circle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionChart(
    List<MapEntry<String, double>> categories,
    double totalSpent,
  ) {
    if (totalSpent == 0) return const SizedBox.shrink();

    return Container(
      height: 12,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE9ECEF),
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: categories.map((entry) {
          final percentage = entry.value / totalSpent;
          return Flexible(
            flex: (percentage * 1000).toInt(),
            child: Builder(
              builder: (context) {
                final cat = context.read<SpendingService>().getCategoryByName(
                  entry.key,
                );
                return Container(color: cat?.color ?? const Color(0xFFCED4DA));
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.spaceGrotesk(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF747780),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildHeroCard(SpendingService spending) {
    final bool isLimitSet = spending.limit > 0;
    final progress = spending.progress;
    final remaining = spending.remaining;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Spent (${spending.period})',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              color: const Color(0xFF747780),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatKsh(spending.spent),
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1D1D1F),
              height: 1.1,
              fontFeatures: [const ui.FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 20),
          if (isLimitSet) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: const Color(0xFFF5F5F7),
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress > 0.9
                      ? const Color(0xFFC25100)
                      : const Color(0xFF0071E3),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(progress * 100).toStringAsFixed(0)}% of limit',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    color: const Color(0xFF747780),
                  ),
                ),
                Text(
                  '${_formatKsh(remaining)} remaining',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: progress > 0.9
                        ? const Color(0xFFC25100)
                        : const Color(0xFF00CC96),
                    fontFeatures: [const ui.FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ] else
            Text(
              'No limit set for this period.',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: const Color(0xFF747780),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(
    BuildContext context,
    MapEntry<String, double> entry,
    double totalSpent,
  ) {
    final spending = context.read<SpendingService>();
    final cat = spending.getCategoryByName(entry.key);
    final percentage = totalSpent > 0 ? (entry.value / totalSpent) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  cat?.color.withValues(alpha: 0.1) ?? const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: HugeIcon(
              icon: cat?.icon ?? HugeIcons.strokeRoundedPackage,
              color: cat?.color ?? const Color(0xFF1D1D1F),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1D1D1F),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${(percentage * 100).toStringAsFixed(1)}% of total',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    color: const Color(0xFF747780),
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatKsh(entry.value),
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1D1D1F),
              fontFeatures: [const ui.FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0071E3), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1D1D1F),
              ),
            ),
          ),
          Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1D1D1F),
              fontFeatures: [const ui.FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(
            CupertinoIcons.doc_text_search,
            size: 48,
            color: Color(0xFFCED4DA),
          ),
          const SizedBox(height: 16),
          Text(
            'No transaction data available',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF747780),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
