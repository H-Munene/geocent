import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/app_transaction.dart';
import '../../services/spending_service.dart';

class GroupedTransactionsList extends StatelessWidget {
  final List<AppTransaction> transactions;
  final void Function(AppTransaction)? onTransactionTap;

  const GroupedTransactionsList({
    super.key,
    required this.transactions,
    this.onTransactionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: Text("No transactions found"),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final tx = transactions[index];
        final prevTx = index > 0 ? transactions[index - 1] : null;

        final bool isNewDay =
            prevTx == null ||
            tx.timestamp.year != prevTx.timestamp.year ||
            tx.timestamp.month != prevTx.timestamp.month ||
            tx.timestamp.day != prevTx.timestamp.day;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isNewDay) _buildDateHeader(tx.timestamp),
            GestureDetector(
              onTap: () => onTransactionTap?.call(tx),
              behavior: HitTestBehavior.opaque,
              child: _buildTransactionRow(context, tx),
            ),
          ],
        );
      }, childCount: transactions.length),
    );
  }

  Widget _buildDateHeader(DateTime date) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        children: [
          Text(
            DateFormat('d').format(date),
            style: GoogleFonts.spaceGrotesk(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1D1D1F),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              DateFormat('E').format(date),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            DateFormat('MM.yyyy').format(date),
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Divider(color: CupertinoColors.systemGrey5, thickness: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionRow(BuildContext context, AppTransaction tx) {
    final spendingService = context.read<SpendingService>();
    final category = spendingService.getCategoryByName(tx.category);
    final isIncome = tx.type == TransactionType.received;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Column 1: Icon
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFF2F2F7),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: _buildCategoryIcon(category),
          ),
          const SizedBox(width: 12),
          // Column 2: Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.merchant,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1D1D1F),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  tx.category ?? 'Unmapped',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
          ),
          // Column 3: Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${isIncome ? '+' : '-'}KES ${tx.amount.toStringAsFixed(2)}",
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isIncome
                      ? CupertinoColors.activeGreen
                      : CupertinoColors.systemRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryIcon(dynamic category) {
    if (category == null || category.icon == null) {
      return const Icon(
        CupertinoIcons.question,
        size: 20,
        color: CupertinoColors.systemGrey,
      );
    }

    final icon = category.icon;
    if (icon is IconData) {
      return Icon(icon, size: 20, color: const Color(0xFF1D1D1F));
    } else {
      return HugeIcon(icon: icon, color: const Color(0xFF1D1D1F), size: 20);
    }
  }
}
