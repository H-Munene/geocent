import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapbox_tut/models/app_transaction.dart';
import 'package:mapbox_tut/screens/location_picker_screen.dart';
import 'category_dropdown_widget.dart';

class UnmappedMessageTile extends StatelessWidget {
  final AppTransaction transaction;
  final bool showDivider;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onSelectToggle;

  const UnmappedMessageTile({
    super.key,
    required this.transaction,
    required this.showDivider,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelectToggle,
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
    final String status = needsMapping
        ? 'Needs mapping'
        : 'Needs categorization';
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
                            color: isSelected
                                ? const Color(0xFF0071E3)
                                : Colors.grey[200],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF0071E3)
                                  : Colors.grey[400]!,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  CupertinoIcons.checkmark,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : null,
                        )
                      : Container(
                          key: const ValueKey('avatar'),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _getAvatarColor(transaction.merchant),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              initial,
                              style: GoogleFonts.spaceGrotesk(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Middle Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          transaction.merchant,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        Text(
                          transaction.formattedAmount,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$status • $timeAgo',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      transaction.rawMessage,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey[500],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 68), // 16 + 40 + 12
            child: Divider(height: 1, thickness: 0.5, color: Colors.grey[200]),
          ),
      ],
    );

    if (isSelectionMode) {
      return GestureDetector(
        onTap: () {
          if (!needsMapping && onSelectToggle != null) {
            onSelectToggle!();
          }
        },
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }

    if (needsMapping) {
      return GestureDetector(
        onTap: () {
          Navigator.of(context, rootNavigator: true).push(
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
        onLongPress: () {
          if (onSelectToggle != null) {
            onSelectToggle!();
          }
        },
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
