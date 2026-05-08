import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_popup/flutter_popup.dart';

class AnalyticsHeader extends StatelessWidget {
  final String dailyAverage;
  final String trendPercentage;
  final bool isTrendPositive;

  const AnalyticsHeader({
    super.key,
    required this.dailyAverage,
    required this.trendPercentage,
    this.isTrendPositive = false,
  });

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
                  'Daily average',
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
                      "Calculated by dividing your total mapped spending this week by the number of days elapsed",
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
              dailyAverage,
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
          child: Row(
            children: [
              Text(
                'Spent ',
                style: GoogleFonts.spaceGrotesk(
                  color: CupertinoColors.systemGrey,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(
                isTrendPositive
                    ? CupertinoIcons.arrowtriangle_up_fill
                    : CupertinoIcons.arrowtriangle_down_fill,
                size: 12,
                color: isTrendPositive
                    ? CupertinoColors.systemRed
                    : CupertinoColors.activeGreen,
              ),
              Text.rich(
                TextSpan(
                  style: GoogleFonts.spaceGrotesk(
                    color: CupertinoColors.systemGrey,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    TextSpan(
                      text: '$trendPercentage ',
                      style: TextStyle(
                        color: isTrendPositive
                            ? CupertinoColors.systemRed
                            : CupertinoColors.activeGreen,
                      ),
                    ),
                    const TextSpan(text: 'from last week'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
