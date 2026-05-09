import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:geocent/models/app_transaction.dart';
import 'package:geocent/screens/location_picker_screen.dart';
import 'package:geocent/services/spending_service.dart';
import 'category_dropdown_widget.dart';

class UnmappedMessageTile extends StatelessWidget {
  final AppTransaction transaction;
  final bool showDivider;
  final bool isSelectionMode;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onLongPress;
  final String? searchQuery;

  const UnmappedMessageTile({
    super.key,
    required this.transaction,
    required this.showDivider,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.isDisabled = false,
    this.onSelectToggle,
    this.onLongPress,
    this.searchQuery,
  });

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
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

  @override
  Widget build(BuildContext context) {
    final bool needsMapping = transaction.latitude == null;
    final String timeAgo = _getTimeAgo(transaction.timestamp);
    final String initial = transaction.merchant.isNotEmpty
        ? transaction.merchant[0].toUpperCase()
        : '?';

    Widget content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Leading Avatar / Checkbox
              SizedBox(
                width: 40,
                height: 40,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return ScaleTransition(scale: animation, child: child);
                      },
                  child: isSelectionMode
                      ? Container(
                          key: const ValueKey('checkbox'),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDisabled
                                ? Colors.grey[100]
                                : isSelected
                                ? const Color(0xFF0071E3)
                                : Colors.grey[200],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDisabled
                                  ? Colors.grey[300]!
                                  : isSelected
                                  ? const Color(0xFF0071E3)
                                  : Colors.grey[400]!,
                              width: 2,
                            ),
                          ),
                          child: isDisabled
                              ? const Icon(
                                  CupertinoIcons.clear,
                                  color: CupertinoColors.systemRed,
                                  size: 18,
                                )
                              : isSelected
                              ? const Icon(
                                  CupertinoIcons.checkmark,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : null,
                        )
                      : Builder(
                          builder: (context) {
                            final spendingService = context
                                .read<SpendingService>();
                            final categoryItem = spendingService
                                .getCategoryByName(transaction.category);

                            final hasValidCategory = categoryItem != null;

                            return Container(
                              key: const ValueKey('avatar'),
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: hasValidCategory
                                    ? spendingService.getCategoryColor(
                                        transaction.category!,
                                      )
                                    : _getAvatarColor(transaction.merchant),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: hasValidCategory
                                    ? HugeIcon(
                                        icon: categoryItem.icon,
                                        color: Colors.white,
                                        size: 20,
                                      )
                                    : Text(
                                        initial,
                                        style: GoogleFonts.spaceGrotesk(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Transaction Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            transaction.merchant,
                            style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: const Color(0xFF1D1D1F),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          transaction.formattedAmount,
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: const Color(0xFF1D1D1F),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    _buildHighlightedMessage(transaction.rawMessage),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                needsMapping
                                    ? CupertinoIcons.location_fill
                                    : transaction.category == null
                                    ? CupertinoIcons.tag_fill
                                    : CupertinoIcons.checkmark_alt,
                                size: 12,
                                color: CupertinoColors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                needsMapping
                                    ? 'Needs mapping'
                                    : transaction.category ??
                                          'Needs categorization',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          timeAgo,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            color: CupertinoColors.systemGrey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 68),
            child: Container(height: 0.5, color: CupertinoColors.systemGrey5),
          ),
      ],
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (isSelectionMode) {
          if (!isDisabled && onSelectToggle != null) {
            onSelectToggle!();
          }
        } else {
          if (needsMapping) {
            Navigator.of(context, rootNavigator: true).push(
              CupertinoPageRoute(
                builder: (context) =>
                    LocationPickerScreen(transactions: [transaction]),
              ),
            );
          } else if (transaction.category == null) {
            // Show categorization popup for messages needing categorization
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
                    onCategorySelected: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
            );
          } else {
            context.read<SpendingService>().selectTransaction(transaction.id);
            Navigator.popUntil(context, (route) => route.isFirst);
          }
        }
      },
      onLongPress: !isSelectionMode ? onLongPress : null,
      child: content,
    );
  }

  Widget _buildHighlightedMessage(String text) {
    if (searchQuery == null || searchQuery!.isEmpty) {
      return Text(
        text,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 13,
          color: CupertinoColors.secondaryLabel,
          height: 1.3,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    final List<TextSpan> spans = [];
    final String lowercaseText = text.toLowerCase();
    final String lowercaseQuery = searchQuery!.toLowerCase();

    int start = 0;
    while (true) {
      final int index = lowercaseText.indexOf(lowercaseQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      spans.add(
        TextSpan(
          text: text.substring(index, index + lowercaseQuery.length),
          style: const TextStyle(
            backgroundColor: Color(0x40FFD700),
            color: Color(0xFF1D1D1F),
            fontWeight: FontWeight.w600,
          ),
        ),
      );

      start = index + lowercaseQuery.length;
    }

    return RichText(
      text: TextSpan(
        style: GoogleFonts.spaceGrotesk(
          fontSize: 13,
          color: CupertinoColors.secondaryLabel,
          height: 1.3,
        ),
        children: spans,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
