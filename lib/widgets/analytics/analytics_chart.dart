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
  final String chartType; // 'Bar', 'Line', 'Pie'

  const AnalyticsChart({
    super.key,
    required this.data,
    required this.categoryColors,
    required this.unmappedColor,
    required this.dateRange,
    this.chartType = 'Bar',
  });

  @override
  State<AnalyticsChart> createState() => _AnalyticsChartState();
}

class _AnalyticsChartState extends State<AnalyticsChart>
    with SingleTickerProviderStateMixin {
  int touchedIndex = -1;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void didUpdateWidget(AnalyticsChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chartType != widget.chartType ||
        oldWidget.data != widget.data) {
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

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
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        Widget chart;
        switch (widget.chartType) {
          case 'Line':
            chart = _buildLineChart();
            break;
          case 'Pie':
            chart = _buildPieChart();
            break;
          default:
            chart = _buildBarChart();
        }

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            if (touchedIndex != -1) {
              setState(() {
                touchedIndex = -1;
              });
            }
          },
          child: AspectRatio(aspectRatio: 1.3, child: chart),
        );
      },
    );
  }

  Widget _buildBarChart() {
    // Dynamically calculate maxY with some padding (20%)
    double maxDailyTotal = 0;
    for (var d in widget.data) {
      if (d.total > maxDailyTotal) maxDailyTotal = d.total;
    }
    double maxY = (maxDailyTotal > 0 ? maxDailyTotal * 1.2 : 2500)
        .ceilToDouble();
    // Ensure maxY is at least 1000 for a better looking empty state
    if (maxY < 1000) maxY = 1000;

    return BarChart(
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
              if (barTouchResponse == null || barTouchResponse.spot == null) {
                setState(() {
                  touchedIndex = -1;
                });
              } else {
                setState(() {
                  touchedIndex = barTouchResponse.spot!.touchedBarGroupIndex;
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
            tooltipBorder: const BorderSide(color: Color(0x1A000000), width: 1),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
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
                final displayName = name.length > 12
                    ? '${name.substring(0, 9)}...'
                    : name;

                children.add(
                  TextSpan(
                    text: '■\u00A0\u00A0',
                    style: TextStyle(color: color, fontSize: 12),
                  ),
                );

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

              double totalSum = 0;
              data.categoryValues.forEach((cat, val) {
                totalSum += val;
                addEntry(cat, val, widget.categoryColors[cat]!);
              });

              if (data.unmappedValue > 0) {
                totalSum += data.unmappedValue;
                addEntry('Unmapped', data.unmappedValue, widget.unmappedColor);
              }

              children.add(
                const TextSpan(
                  text: '──────────────────────\n',
                  style: TextStyle(
                    color: CupertinoColors.systemGrey5,
                    fontSize: 10,
                  ),
                ),
              );

              children.add(
                const TextSpan(
                  text: '■\u00A0\u00A0',
                  style: TextStyle(color: Colors.transparent, fontSize: 12),
                ),
              );

              children.add(
                TextSpan(
                  text: 'TOTAL'.padRight(14),
                  style: GoogleFonts.spaceMono(
                    color: CupertinoColors.systemGrey,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );

              children.add(
                TextSpan(
                  text: 'KES\u00A0${totalSum.toInt()}\n',
                  style: GoogleFonts.spaceMono(
                    color: CupertinoColors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              );

              if (children.isNotEmpty && children.last.text!.endsWith('\n')) {
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
              interval: 1,
              getTitlesWidget: (value, meta) {
                final int index = value.toInt();
                if (index < 0 || index >= widget.data.length) {
                  return const SizedBox.shrink();
                }

                final data = widget.data[index];

                // For Month view, show all day numbers to satisfy "not skipping a single day"
                // If the font is small enough (8-9), it should fit.
                if (widget.data.length > 7 && widget.data.length <= 31) {
                  // Only show label every day but make it small
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
                        fontSize: 8,
                      ),
                    ),
                  );
                }

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
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52, // Increased from 46 to allow for spacing
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();

                String text;
                if (value >= 1000) {
                  text =
                      'KES ${(value / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}k';
                } else {
                  text = 'KES ${value.toInt()}';
                }

                return Padding(
                  padding: const EdgeInsets.only(
                    right: 12.0,
                  ), // Spacing from Y axis
                  child: Text(
                    text,
                    style: GoogleFonts.spaceGrotesk(
                      color: CupertinoColors.systemGrey,
                      fontSize: 10,
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
            bottom: BorderSide(color: CupertinoColors.systemGrey4, width: 1),
            left: BorderSide(color: CupertinoColors.systemGrey4, width: 1),
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
                currentY * _animation.value,
                (currentY + val) * _animation.value,
                widget.categoryColors[cat]!,
              ),
            );
            currentY += val;
          });
          if (data.unmappedValue > 0) {
            stackItems.add(
              BarChartRodStackItem(
                currentY * _animation.value,
                (currentY + data.unmappedValue) * _animation.value,
                widget.unmappedColor,
              ),
            );
            currentY += data.unmappedValue;
          }

          final isTouched = touchedIndex == index;

          return BarChartGroupData(
            x: index,
            barsSpace: -30,
            showingTooltipIndicators: isTouched ? [1] : [],
            barRods: [
              BarChartRodData(
                toY: maxY,
                width: 36,
                color: isTouched
                    ? CupertinoColors.activeBlue.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.zero,
              ),
              BarChartRodData(
                toY: currentY * _animation.value,
                width: 24,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
                rodStackItems: stackItems,
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLineChart() {
    double maxDailyTotal = 0;
    for (var d in widget.data) {
      if (d.total > maxDailyTotal) maxDailyTotal = d.total;
    }
    double maxY = (maxDailyTotal > 0 ? maxDailyTotal * 1.2 : 2500)
        .ceilToDouble();
    if (maxY < 1000) maxY = 1000;

    // Find the last index with non-zero data to "hang" the line
    int lastDataIndex = -1;
    for (int i = 0; i < widget.data.length; i++) {
      if (widget.data[i].total > 0 || widget.data[i].isToday) {
        lastDataIndex = i;
      }
    }

    // If no data at all, just show the first point at 0
    if (lastDataIndex == -1) lastDataIndex = 0;

    return LineChart(
      LineChartData(
        maxY: maxY,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => CupertinoColors.white,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((spot) {
                final data = widget.data[spot.x.toInt()];
                return LineTooltipItem(
                  "${data.dayName}\nKES ${spot.y.toInt()}",
                  GoogleFonts.spaceGrotesk(
                    color: CupertinoColors.black,
                    fontWeight: FontWeight.w700,
                  ),
                );
              }).toList();
            },
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
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final int index = value.toInt();
                if (index < 0 || index >= widget.data.length) {
                  return const SizedBox.shrink();
                }

                final data = widget.data[index];

                // For Month view, show all day numbers to satisfy "not skipping a single day"
                if (widget.data.length > 7 && widget.data.length <= 31) {
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
                        fontSize: 8,
                      ),
                    ),
                  );
                }

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
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52, // Increased for spacing
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                String text = value >= 1000
                    ? 'KES ${(value / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}k'
                    : 'KES ${value.toInt()}';
                return Padding(
                  padding: const EdgeInsets.only(
                    right: 12.0,
                  ), // Spacing from Y axis
                  child: Text(
                    text,
                    style: GoogleFonts.spaceGrotesk(
                      color: CupertinoColors.systemGrey,
                      fontSize: 10,
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
            bottom: BorderSide(color: CupertinoColors.systemGrey4),
            left: BorderSide(color: CupertinoColors.systemGrey4),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: widget.data.asMap().entries.take(lastDataIndex + 1).map((e) {
              return FlSpot(e.key.toDouble(), e.value.total * _animation.value);
            }).toList(),
            isCurved: true,
            color: CupertinoColors.activeBlue,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: CupertinoColors.activeBlue.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    final Map<String, double> categoryTotals = {};
    double totalUnmapped = 0;
    double overallTotal = 0;

    for (var d in widget.data) {
      d.categoryValues.forEach((cat, val) {
        categoryTotals[cat] = (categoryTotals[cat] ?? 0) + val;
        overallTotal += val;
      });
      totalUnmapped += d.unmappedValue;
      overallTotal += d.unmappedValue;
    }

    final List<PieChartSectionData> sections = [];
    categoryTotals.forEach((cat, val) {
      if (val > 0) {
        final percentage = (val / overallTotal) * 100;
        sections.add(
          PieChartSectionData(
            color: widget.categoryColors[cat]!,
            value: val * _animation.value,
            title: percentage >= 5 ? '${percentage.toInt()}%' : '',
            radius: 50,
            showTitle: true,
            titleStyle: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.white,
            ),
          ),
        );
      }
    });

    if (totalUnmapped > 0) {
      final percentage = (totalUnmapped / overallTotal) * 100;
      sections.add(
        PieChartSectionData(
          color: widget.unmappedColor,
          value: totalUnmapped * _animation.value,
          title: percentage >= 5 ? '${percentage.toInt()}%' : '',
          radius: 50,
          showTitle: true,
          titleStyle: GoogleFonts.spaceGrotesk(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: CupertinoColors.white,
          ),
        ),
      );
    }

    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 40,
        sectionsSpace: 2,
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {
            setState(() {
              if (!event.isInterestedForInteractions ||
                  pieTouchResponse == null ||
                  pieTouchResponse.touchedSection == null) {
                touchedIndex = -1;
                return;
              }
              touchedIndex =
                  pieTouchResponse.touchedSection!.touchedSectionIndex;
            });
          },
        ),
      ),
    );
  }
}
