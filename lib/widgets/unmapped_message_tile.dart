import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapbox_tut/models/app_transaction.dart';
import 'package:mapbox_tut/screens/location_picker_screen.dart';
import 'category_dropdown_widget.dart';

class UnmappedMessageTile extends StatelessWidget {
  final AppTransaction transaction;
  final bool showDivider;

  const UnmappedMessageTile({
    super.key,
    required this.transaction,
    required this.showDivider,
  });

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  @override
  Widget build(BuildContext context) {
    final bool needsMapping = transaction.latitude == null;
    final String status = needsMapping
        ? 'Needs mapping'
        : 'Needs categorization';
    final String timeAgo = _getTimeAgo(transaction.timestamp);

    Widget content = Container(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.merchant,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1D1D1F),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$status • $timeAgo',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF747780),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  transaction.formattedAmount,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1D1D1F),
                    fontFeatures: [const ui.FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          if (showDivider)
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Divider(
                height: 1,
                thickness: 1,
                color: const Color(0xFFE9ECEF),
              ),
            ),
        ],
      ),
    );

    if (needsMapping) {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) =>
                  LocationPickerScreen(transaction: transaction),
            ),
          );
        },
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    } else {
      return GestureDetector(
        onTap: () {
          showCupertinoDialog(
            context: context,
            barrierDismissible: true,
            builder: (context) => Center(
              child: DefaultTextStyle(
                style: GoogleFonts.spaceGrotesk(
                  color: CupertinoColors.label,
                  decoration: TextDecoration.none,
                ),
                child: CategoryDropdownWidget(
                  transactionId: transaction.id,
                  currentCategory: transaction.category,
                  onCategorySelected: () => Navigator.pop(context),
                ),
              ),
            ),
          );
        },
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }
  }
}
