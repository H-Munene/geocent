import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/app_transaction.dart';
import '../services/spending_service.dart';
import '../widgets/unmapped_message_tile.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  Map<String, List<AppTransaction>> _groupTransactions(
    List<AppTransaction> transactions,
  ) {
    final Map<String, List<AppTransaction>> groups = {
      'Today': [],
      'Yesterday': [],
      'Older': [],
    };

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var tx in transactions) {
      final txDate = DateTime(
        tx.timestamp.year,
        tx.timestamp.month,
        tx.timestamp.day,
      );
      if (txDate == today) {
        groups['Today']!.add(tx);
      } else if (txDate == yesterday) {
        groups['Yesterday']!.add(tx);
      } else {
        groups['Older']!.add(tx);
      }
    }

    // Remove empty groups
    groups.removeWhere((key, value) => value.isEmpty);
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final spendingService = context.watch<SpendingService>();
    final groupedMessages = _groupTransactions(
      spendingService.actionableTransactions,
    );

    return CupertinoPageScaffold(
      backgroundColor: Colors.white,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Colors.white.withValues(alpha: 0.8),
        border: null,
        middle: Text(
          'Messages',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      child: SafeArea(
        child: groupedMessages.isEmpty
            ? Center(
                child: Text(
                  'No pending actions',
                  style: GoogleFonts.spaceGrotesk(
                    color: CupertinoColors.systemGrey,
                    fontSize: 16,
                  ),
                ),
              )
            : ListView(
                children: groupedMessages.entries.expand((entry) {
                  final String title = entry.key;
                  final List<AppTransaction> transactions = entry.value;

                  return [
                    _SectionHeader(title: title),
                    ...transactions.asMap().entries.map((messageEntry) {
                      final int index = messageEntry.key;
                      final AppTransaction transaction = messageEntry.value;
                      final bool isLast = index == transactions.length - 1;

                      return UnmappedMessageTile(
                        transaction: transaction,
                        showDivider: !isLast,
                      );
                    }),
                  ];
                }).toList(),
              ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.black,
        ),
      ),
    );
  }
}