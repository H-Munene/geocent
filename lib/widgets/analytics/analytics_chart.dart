import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/daily_spending.dart';

class AnalyticsChart extends StatefulWidget {
  final List<DailySpending> data;
  final Map<String, Color> categoryColors;
  final Color unmappedColor;
  final String dateRange;

  const AnalyticsChart({
    super.key,
    required this.data,
    required this.categoryColors,
    required this.unmappedColor,
    required this.dateRange,
  });

  @override
  State<AnalyticsChart> createState() => _AnalyticsChartState();
}

class _AnalyticsChartState extends State<AnalyticsChart> {
  int touchedIndex = -1;

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    // Dynamically calculate maxY with some padding (20%)
    double maxDailyTotal = 0;
    for (var d in widget.data) {
      if (d.total > maxDailyTotal) maxDailyTotal = d.total;
    }
    double maxY = (maxDailyTotal > 0 ? maxDailyTotal * 1.2 : 2500)
        .ceilToDouble();
    // Ensure maxY is at least 1000 for a better looking empty state
    if (maxY < 1000) maxY = 1000;

    return Column(
      children: [
        Text(
          widget.dateRange,
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: CupertinoColors.black,
          ),
        ),
        const SizedBox(height: 32),
        AspectRatio(
          aspectRatio: 1.3,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceEvenly,
              maxY: maxY,
              barTouchData: BarTouchData(
                enabled: true,
                handleBuiltInTouches: false,
                touchCallback: (FlTouchEvent event, barTouchResponse) {
                  if (event is FlTapUpEvent ||
                      event is FlTapDownEvent ||
                      event is FlLongPressStart) {
                    if (barTouchResponse == null ||
                        barTouchResponse.spot == null) {
                      setState(() {
                        touchedIndex = -1;
                      });
                    } else {
                      setState(() {
                        touchedIndex =
                            barTouchResponse.spot!.touchedBarGroupIndex;
                      });
                    }
                  }
                },
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => CupertinoColors.white,
                  tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  tooltipMargin: 0,
                  tooltipHorizontalAlignment: FLHorizontalAlignment.right,
                  tooltipHorizontalOffset: 12,
                  maxContentWidth: 250,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  tooltipBorder: const BorderSide(
                    color: Color(0x1A000000),
                    width: 1,
                  ),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    // rodIndex 1 is the actual data rod
                    if (rodIndex == 0) return null;

                    final data = widget.data[groupIndex];
                    final dateStr =
                        "${data.date.day} ${_getMonthName(data.date.month)}";
                    List<TextSpan> children = [];

                    children.add(
                      const TextSpan(
                        text: '\n---------\n',
                        style: TextStyle(
                          color: CupertinoColors.systemGrey5,
                          fontSize: 10,
                        ),
                      ),
                    );

                    void addEntry(String name, double val, Color color) {
                      // Manual truncation for category name
                      final displayName = name.length > 12
                          ? '${name.substring(0, 9)}...'
                          : name;

                      children.add(
                        TextSpan(
                          text: '■\u00A0\u00A0',
                          style: TextStyle(color: color, fontSize: 12),
                        ),
                      );

                      // Use padRight on a Monospace font to create a rigid column effect.
                      // 14 characters ensures the 'KES' string always starts at the same spot.
                      final rigidName = displayName.padRight(14);

                      children.add(
                        TextSpan(
                          text: rigidName,
                          style: GoogleFonts.spaceMono(
                            color: CupertinoColors.systemGrey,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );

                      // Using non-breaking spaces (\u00A0) ensures the monetary value never wraps.
                      // Using spaceMono here as well keeps the character alignment perfect.
                      children.add(
                        TextSpan(
                          text: 'KES\u00A0${val.toInt()}\n',
                          style: GoogleFonts.spaceMono(
                            color: CupertinoColors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }

                    data.categoryValues.forEach((cat, val) {
                      addEntry(cat, val, widget.categoryColors[cat]!);
                    });

                    if (data.unmappedValue > 0) {
                      addEntry(
                        'Unmapped',
                        data.unmappedValue,
                        widget.unmappedColor,
                      );
                    }

                    if (children.isNotEmpty &&
                        children.last.text!.endsWith('\n')) {
                      final last = children.removeLast();
                      children.add(
                        TextSpan(
                          text: last.text!.substring(0, last.text!.length - 1),
                          style: last.style,
                        ),
                      );
                    }

                    return BarTooltipItem(
                      dateStr,
                      GoogleFonts.spaceGrotesk(
                        color: CupertinoColors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      children: children,
                      textAlign: TextAlign.left,
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final data = widget.data[value.toInt()];
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          data.dayName,
                          style: GoogleFonts.spaceGrotesk(
                            color: data.isToday
                                ? CupertinoColors.black
                                : CupertinoColors.systemGrey,
                            fontWeight: data.isToday
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 46,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(
                          'Ksh ${(value / 1000).toStringAsFixed(value < 1000 ? 1 : 0)}k',
                          style: GoogleFonts.spaceGrotesk(
                            color: CupertinoColors.systemGrey,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: const Border(
                  bottom: BorderSide(
                    color: CupertinoColors.systemGrey4,
                    width: 1,
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: (maxY / 3).ceil().toDouble(),
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: CupertinoColors.systemGrey5,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  );
                },
              ),
              barGroups: widget.data.asMap().entries.map((e) {
                final index = e.key;
                final data = e.value;

                double currentY = 0;
                List<BarChartRodStackItem> stackItems = [];

                data.categoryValues.forEach((cat, val) {
                  stackItems.add(
                    BarChartRodStackItem(
                      currentY,
                      currentY + val,
                      widget.categoryColors[cat]!,
                    ),
                  );
                  currentY += val;
                });
                if (data.unmappedValue > 0) {
                  stackItems.add(
                    BarChartRodStackItem(
                      currentY,
                      currentY + data.unmappedValue,
                      widget.unmappedColor,
                    ),
                  );
                  currentY += data.unmappedValue;
                }

                final isTouched = touchedIndex == index;

                return BarChartGroupData(
                  x: index,
                  barsSpace:
                      -30, // Overlap the two rods to create the wider background effect
                  showingTooltipIndicators: isTouched ? [1] : [],
                  barRods: [
                    // Rod 1: Wider Background Highlight
                    BarChartRodData(
                      toY: maxY,
                      width: 36, // Bigger than inner bar
                      color: isTouched
                          ? CupertinoColors.activeBlue.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.zero, // No border radius
                    ),
                    // Rod 2: Actual Data Bar
                    BarChartRodData(
                      toY: currentY,
                      width: 24, // Inner bar
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                      rodStackItems: stackItems,
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
