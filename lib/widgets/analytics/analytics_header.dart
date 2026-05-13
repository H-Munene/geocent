import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_popup/flutter_popup.dart';
import '../../services/spending_service.dart';
import 'analytics_selector_modal.dart';

class AnalyticsHeader extends StatelessWidget {
  final String spentThisWeek;
  final String trendPercentage;
  final bool isTrendPositive;
  final String selectedChartType;
  final ValueChanged<String> onChartTypeChanged;
  final AnalyticsRangeMode rangeMode;

  const AnalyticsHeader({
    super.key,
    required this.spentThisWeek,
    required this.trendPercentage,
    this.isTrendPositive = false,
    this.selectedChartType = 'Bar',
    required this.onChartTypeChanged,
    this.rangeMode = AnalyticsRangeMode.week,
  });

  void _showChartTypePicker(BuildContext context) {
    final bool isBarDisabled =
        rangeMode == AnalyticsRangeMode.month ||
        rangeMode == AnalyticsRangeMode.year;

    showCupertinoModalPopup(
      context: context,
      builder: (modalContext) => AnalyticsSelectorModal(
        title: 'Chart Type',
        children: [
          if (!isBarDisabled)
            SelectorOption(
              label: 'Bar chart',
              isActive: selectedChartType == 'Bar',
              onTap: () {
                onChartTypeChanged('Bar');
                Navigator.pop(modalContext);
              },
            ),
          SelectorOption(
            label: 'Line chart',
            isActive: selectedChartType == 'Line',
            onTap: () {
              onChartTypeChanged('Line');
              Navigator.pop(modalContext);
            },
          ),
          SelectorOption(
            label: 'Pie chart',
            isActive: selectedChartType == 'Pie',
            onTap: () {
              onChartTypeChanged('Pie');
              Navigator.pop(modalContext);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Column 1 (Context)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Spent this week',
                  style: GoogleFonts.spaceGrotesk(
                    color: CupertinoColors.systemGrey,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
                CustomPopup(
                  content: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "The sum of all spending since the beginning of this week",
                      style: GoogleFonts.spaceGrotesk(fontSize: 12),
                    ),
                  ),
                  backgroundColor: CupertinoColors.white,
                  child: const Icon(
                    CupertinoIcons.info_circle,
                    size: 16,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              spentThisWeek,
              style: GoogleFonts.spaceGrotesk(
                color: CupertinoColors.black,
                fontWeight: FontWeight.w900,
                fontSize: 32,
              ),
            ),
          ],
        ),
        // Column 2 (Data)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => _showChartTypePicker(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$selectedChartType chart',
                        style: GoogleFonts.spaceGrotesk(
                          color: CupertinoColors.activeBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        CupertinoIcons.chevron_down,
                        size: 12,
                        color: CupertinoColors.activeBlue,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
