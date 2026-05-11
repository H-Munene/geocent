import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geocent/models/app_transaction.dart';
import 'package:geocent/services/spending_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

class TimelineSheet extends StatelessWidget {
  final Function(AppTransaction)? onTransactionSelected;

  const TimelineSheet({super.key, this.onTransactionSelected});

  @override
  Widget build(BuildContext context) {
    final spendingService = context.watch<SpendingService>();
    final now = DateTime.now();

    // Filter today's mapped transactions and sort descending
    final todayTxs = spendingService.mappedTransactions.where((tx) {
      return tx.timestamp.year == now.year &&
          tx.timestamp.month == now.month &&
          tx.timestamp.day == now.day;
    }).toList();

    todayTxs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey4,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Today\'s Timeline',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: CupertinoColors.systemGrey,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: todayTxs.isEmpty
                ? Center(
                    child: Text(
                      'No transactions today',
                      style: GoogleFonts.spaceGrotesk(
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    itemCount: todayTxs.length,
                    itemBuilder: (context, index) {
                      final tx = todayTxs[index];
                      final isFirst = index == 0;
                      final isLast = index == todayTxs.length - 1;

                      return _buildTimelineItem(
                        context,
                        tx,
                        isFirst,
                        isLast,
                        spendingService,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(
    BuildContext context,
    AppTransaction tx,
    bool isFirst,
    bool isLast,
    SpendingService spendingService,
  ) {
    final hour = tx.timestamp.hour == 0
        ? 12
        : (tx.timestamp.hour > 12 ? tx.timestamp.hour - 12 : tx.timestamp.hour);
    final minute = tx.timestamp.minute.toString().padLeft(2, '0');
    final period = tx.timestamp.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:$minute $period';
    final cat = spendingService.getCategoryByName(tx.category);
    final color = spendingService.getCategoryColor(tx.category ?? '');

    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTransactionSelected?.call(tx);
      },
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left: Time
            SizedBox(
              width: 50,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  timeStr,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    color: CupertinoColors.systemGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            // Middle: Timeline Line and Circle
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: 1,
                      color: isFirst
                          ? Colors.transparent
                          : CupertinoColors.systemGrey5,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 1),
                    ),
                    child: cat != null && cat.icon is IconData
                        ? Icon(cat.icon as IconData, color: color, size: 16)
                        : HugeIcon(
                            icon: cat?.icon ?? HugeIcons.strokeRoundedTag01,
                            color: color,
                            size: 16,
                          ),
                  ),
                  Expanded(
                    child: Container(
                      width: 1,
                      color: isLast
                          ? Colors.transparent
                          : CupertinoColors.systemGrey5,
                    ),
                  ),
                ],
              ),
            ),

            // Right: Merchant and Price
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        tx.merchant,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      tx.formattedAmount,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
