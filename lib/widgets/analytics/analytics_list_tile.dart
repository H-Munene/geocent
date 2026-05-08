import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../models/analytics_item.dart';
import '../../utils/categories.dart';

class AnalyticsListTile extends StatelessWidget {
  final AnalyticsItem item;
  final Color categoryColor;

  const AnalyticsListTile({
    super.key,
    required this.item,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Leading
          _buildLeading(),
          const SizedBox(width: 16),
          // Middle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.count} Transactions',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.grey[500],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Trailing
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'KES ${item.total.toInt().toString().replaceAllMapped(RegExp(r"\B(?=(\d{3})+(?!\d))"), (m) => ",")}',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
              if (item.trend != null) ...[
                const SizedBox(height: 2),
                _buildTrend(),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeading() {
    if (item.initials != null) {
      // Recipient Leading: Show only the first character in a circle
      final firstChar = item.title.isNotEmpty
          ? item.title[0].toUpperCase()
          : '?';
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _getAvatarColor(item.title),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            firstChar,
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    // Category Leading: Show the category icon in a rounded square
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: categoryColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: HugeIcon(
          icon: _getIconForCategory(item.title),
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Color _getAvatarColor(String merchant) {
    final colors = [
      const Color(0xFF007AFF), // iOS Blue
      const Color(0xFF34C759), // iOS Green
      const Color(0xFFFF9500), // iOS Orange
      const Color(0xFFAF52DE), // iOS Purple
      const Color(0xFFFF2D55), // iOS Pink
      const Color(0xFF5856D6), // iOS Indigo
      const Color(0xFF00C7BE), // iOS Teal
      const Color(0xFF30B0C7), // iOS Cyan
    ];
    // Simple hash to ensure same merchant always gets same color
    final int hash = merchant
        .split('')
        .fold(0, (prev, char) => prev + char.codeUnitAt(0));
    return colors[hash % colors.length];
  }

  Widget _buildTrend() {
    final isDown = item.isTrendNegative;
    final color = isDown ? Colors.green : Colors.red;
    final icon = isDown
        ? CupertinoIcons.arrowtriangle_down_fill
        : CupertinoIcons.arrowtriangle_up_fill;
    final absTrend = item.trend!.abs().toInt().toString().replaceAllMapped(
      RegExp(r"\B(?=(\d{3})+(?!\d))"),
      (m) => ",",
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 4),
        Text(
          'KES $absTrend',
          style: GoogleFonts.spaceGrotesk(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  dynamic _getIconForCategory(String name) {
    final cat = availableIcons.values.where((c) => c.name == name).firstOrNull;
    return cat?.icon ?? HugeIcons.strokeRoundedCircle;
  }
}
