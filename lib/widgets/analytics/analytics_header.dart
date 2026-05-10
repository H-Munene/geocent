import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_popup/flutter_popup.dart';

class AnalyticsHeader extends StatelessWidget {
  final String spentThisWeek;
  final String trendPercentage;
  final bool isTrendPositive;

  const AnalyticsHeader({
    super.key,
    required this.spentThisWeek,
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
