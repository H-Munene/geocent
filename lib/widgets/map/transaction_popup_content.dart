import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_popup/flutter_popup.dart';
import 'package:geocent/models/map_place.dart';
import 'package:geocent/services/spending_service.dart';
import 'package:geocent/widgets/category_dropdown_widget.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

class TransactionPopupContent extends StatelessWidget {
  final MapPlace place;

  const TransactionPopupContent({super.key, required this.place});

  @override
  Widget build(BuildContext context) {
    final spending = context.watch<SpendingService>();
    final cat = spending.getCategoryByName(place.category);

    return DefaultTextStyle(
      style: GoogleFonts.spaceGrotesk(
        color: Colors.black,
        decoration: TextDecoration.none,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(
              builder: (context) {
                return CustomPopup(
                  barrierColor: CupertinoColors.transparent,
                  contentPadding: EdgeInsets.zero,
                  content: CategoryDropdownWidget(
                    transactionId: place.id,
                    currentCategory: place.category,
                    onCategorySelected: () {
                      HapticFeedback.lightImpact();
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: cat == null
                          ? CupertinoColors.systemGrey5
                          : spending
                                .getCategoryColor(cat.name)
                                .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (cat != null) ...[
                          HugeIcon(
                            icon: cat.icon,
                            color: spending.getCategoryColor(cat.name),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          place.category ?? 'Set Category',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: cat == null
                                ? CupertinoColors.systemGrey
                                : spending.getCategoryColor(cat.name),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: Colors.black.withValues(alpha: 0.1)),
            const SizedBox(height: 12),
            Text(
              place.transactions.first.rawMessage,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                height: 1.5,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
