import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geocent/models/map_place.dart';
import 'package:geocent/services/spending_service.dart';
import 'package:geocent/widgets/category_dropdown_widget.dart';
import 'package:geocent/widgets/custom_toast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

class GroupedTransactionsSheet extends StatelessWidget {
  final MapPlace place;
  final Function(String) onTransactionSelected;

  const GroupedTransactionsSheet({
    super.key,
    required this.place,
    required this.onTransactionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final spending = context.watch<SpendingService>();
    final totalFormatted = 'KES ${place.totalAmount.toStringAsFixed(0)}';
    final cat = spending.getCategoryByName(place.category);

    return Container(
      color: CupertinoColors.systemBackground,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          place.name,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Icon(
                          CupertinoIcons.xmark_circle_fill,
                          color: CupertinoColors.systemGrey3,
                          size: 28,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildStandardPill(
                          text: totalFormatted,
                          bgColor: const Color(0xFF1D1D1F),
                          textColor: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        _buildStandardPill(
                          text: '${place.transactions.length} messages',
                          bgColor: CupertinoColors.systemGrey6,
                          textColor: CupertinoColors.secondaryLabel,
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            showCupertinoDialog(
                              context: context,
                              barrierDismissible: true,
                              builder: (dialogContext) => Center(
                                child: DefaultTextStyle(
                                  style: GoogleFonts.spaceGrotesk(
                                    color: CupertinoColors.label,
                                    decoration: TextDecoration.none,
                                  ),
                                  child: CategoryDropdownWidget(
                                    onCategorySelectedOverride:
                                        (categoryName) async {
                                          final ids = place.transactions
                                              .map((tx) => tx.id)
                                              .toList();
                                          final dialogNavigator = Navigator.of(
                                            dialogContext,
                                          );
                                          final sheetNavigator = Navigator.of(
                                            context,
                                          );

                                          await spending.bulkUpdateCategory(
                                            ids,
                                            categoryName,
                                          );

                                          dialogNavigator.pop(); // Pop picker
                                          sheetNavigator.pop(); // Pop sheet
                                          showCustomToast(
                                            '${place.transactions.length} messages successfully categorized',
                                          );
                                        },
                                  ),
                                ),
                              ),
                            );
                          },
                          child: _buildStandardPill(
                            text: cat?.name ?? 'Set Category',
                            bgColor: cat == null
                                ? CupertinoColors.systemGrey5
                                : spending
                                      .getCategoryColor(cat.name)
                                      .withValues(alpha: 0.15),
                            textColor: cat == null
                                ? CupertinoColors.systemGrey
                                : spending.getCategoryColor(cat.name),
                            icon: cat != null ? cat.icon : CupertinoIcons.tag,
                            isCategory: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: place.transactions.length,
                separatorBuilder: (context, index) =>
                    const Divider(indent: 20, endIndent: 20),
                itemBuilder: (context, index) {
                  final tx = place.transactions[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onTransactionSelected(tx.id);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                tx.formattedAmount,
                                style: GoogleFonts.spaceGrotesk(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                _formatDate(tx.timestamp),
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12,
                                  color: CupertinoColors.secondaryLabel,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tx.rawMessage,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 13,
                              color: CupertinoColors.label,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandardPill({
    required String text,
    required Color bgColor,
    required Color textColor,
    dynamic icon,
    bool isCategory = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: isCategory
            ? Border.all(color: textColor.withValues(alpha: 0.3), width: 1.5)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            if (icon is IconData)
              Icon(icon, color: textColor, size: 16)
            else
              HugeIcon(icon: icon, color: textColor, size: 16),
            const SizedBox(width: 8),
          ],
          Text(
            text,
            style: GoogleFonts.spaceGrotesk(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
