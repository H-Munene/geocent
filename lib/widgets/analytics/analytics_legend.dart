import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class AnalyticsLegend extends StatelessWidget {
  final Map<String, Color> categoryColors;
  final Color unmappedColor;

  const AnalyticsLegend({
    super.key,
    required this.categoryColors,
    required this.unmappedColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Center(
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            ...categoryColors.entries.map(
              (e) => _buildLegendItem(e.key, e.value),
            ),
            _buildLegendItem('Unmapped', unmappedColor),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String name, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          name,
          style: GoogleFonts.spaceGrotesk(
            color: CupertinoColors.systemGrey,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
