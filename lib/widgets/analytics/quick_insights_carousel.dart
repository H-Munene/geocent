import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/spending_service.dart';
import '../../models/quick_insights.dart';

class QuickInsightsCarousel extends StatefulWidget {
  const QuickInsightsCarousel({super.key});

  @override
  State<QuickInsightsCarousel> createState() => _QuickInsightsCarouselState();
}

class _QuickInsightsCarouselState extends State<QuickInsightsCarousel> {
  Timer? _timer;
  int _indexPrimary = 0;
  int _indexTopCategory = 0;
  int _indexCounts = 0;
  int _indexMonthly = 0;

  @override
  void initState() {
    super.initState();
    _startRotation();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startRotation() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;

      final data = context.read<SpendingService>().quickInsightsData;

      // Staggered updates
      // 1. Primary
      if (data.primary.isNotEmpty) {
        setState(() {
          _indexPrimary = (_indexPrimary + 1) % data.primary.length;
        });
      }

      // 2. Top Category (Stagger 600ms)
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted || data.topCategories.isEmpty) return;
        setState(() {
          _indexTopCategory =
              (_indexTopCategory + 1) % data.topCategories.length;
        });
      });

      // 3. Counts (Stagger 1200ms)
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted || data.counts.isEmpty) return;
        setState(() {
          _indexCounts = (_indexCounts + 1) % data.counts.length;
        });
      });

      // 4. Monthly (Stagger 1800ms)
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (!mounted || data.monthly.isEmpty) return;
        setState(() {
          _indexMonthly = (_indexMonthly + 1) % data.monthly.length;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final spendingService = context.watch<SpendingService>();
    final data = spendingService.quickInsightsData;

    if (data.primary.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 220,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Column (Primary & Monthly)
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Primary Container
                Expanded(
                  flex: 3,
                  child: _buildPrimaryBox(
                    data.primary[_indexPrimary % data.primary.length],
                  ),
                ),
                const SizedBox(height: 12),
                // Monthly Container
                Expanded(
                  flex: 1,
                  child: data.monthly.isEmpty
                      ? const SizedBox.shrink()
                      : _buildMonthlyBox(
                          data.monthly[_indexMonthly % data.monthly.length],
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Right Column (Top Category & Counts)
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Category Container
                Expanded(
                  flex: 1,
                  child: data.topCategories.isEmpty
                      ? _buildEmptyBox("No spending today")
                      : _buildTopCategoryBox(
                          data.topCategories[_indexTopCategory %
                              data.topCategories.length],
                        ),
                ),
                const SizedBox(height: 12),
                // Counts Container
                Expanded(
                  flex: 2,
                  child: data.counts.isEmpty
                      ? const SizedBox.shrink()
                      : _buildCountsBox(
                          data.counts[_indexCounts % data.counts.length],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryBox(QuickInsightPrimary item) {
    return Container(
      key: const ValueKey('primary_container'),
      decoration: BoxDecoration(
        color: const Color(0xFF0A84FF),
        borderRadius: BorderRadius.circular(5),
      ),
      padding: const EdgeInsets.all(20),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 800),
        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
          return Stack(
            alignment: Alignment.topLeft,
            children: <Widget>[...previousChildren, ?currentChild],
          );
        },
        transitionBuilder: (child, animation) {
          final offsetAnimation =
              Tween<Offset>(
                begin: const Offset(-1.0, 0.0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOutCubic,
                ),
              );

          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offsetAnimation, child: child),
          );
        },
        child: Column(
          key: ValueKey(item.label),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              item.label.toUpperCase(),
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
              ),
            ),
            Text(
              'KES ${item.amount.toInt().toString().replaceAllMapped(RegExp(r"\B(?=(\d{3})+(?!\d))"), (m) => ",")}',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCategoryBox(QuickInsightCategory item) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        color: item.color,
        borderRadius: BorderRadius.circular(5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
          return Stack(
            alignment: Alignment.centerLeft,
            children: <Widget>[...previousChildren, ?currentChild],
          );
        },
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0.0, 1.0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOutCubic,
                    ),
                  ),
              child: child,
            ),
          );
        },
        child: Column(
          key: ValueKey(item.categoryName),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Highest Category",
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
              children: [
                Icon(item.icon, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.categoryName,
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountsBox(QuickInsightCounts item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: CupertinoColors.systemGrey5),
      ),
      padding: const EdgeInsets.all(16),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
          return Stack(
            alignment: Alignment.centerLeft,
            children: <Widget>[...previousChildren, ?currentChild],
          );
        },
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(1.0, 0.0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOutCubic,
                    ),
                  ),
              child: child,
            ),
          );
        },
        child: Column(
          key: ValueKey(item.period),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildCountRow("Mapped", item.mapped, item.period),
            const Divider(height: 12, color: CupertinoColors.systemGrey6),
            _buildCountRow("Categorized", item.categorized, item.period),
          ],
        ),
      ),
    );
  }

  Widget _buildCountRow(String label, int count, String period) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$label $period",
          style: GoogleFonts.spaceGrotesk(
            color: CupertinoColors.systemGrey,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          "$count",
          style: GoogleFonts.spaceGrotesk(
            color: const Color(0xFF1D1D1F),
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyBox(QuickInsightMonthly item) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A84FF),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
          return Stack(
            alignment: Alignment.centerLeft,
            children: <Widget>[...previousChildren, ?currentChild],
          );
        },
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0.0, -1.0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOutCubic,
                    ),
                  ),
              child: child,
            ),
          );
        },
        child: Column(
          key: ValueKey(item.monthName),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Spent on ${item.monthName}",
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              "KES ${item.amount.toInt().toString().replaceAllMapped(RegExp(r"\B(?=(\d{3})+(?!\d))"), (m) => ",")}",
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyBox(String message) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(5),
      ),
      alignment: Alignment.center,
      child: Text(
        message,
        style: GoogleFonts.spaceGrotesk(
          color: CupertinoColors.systemGrey,
          fontSize: 12,
        ),
      ),
    );
  }
}
