import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import '../utils/lottie_files.dart';
import 'empty_state_widget.dart';
import '../models/app_transaction.dart';
import '../services/spending_service.dart';
import 'custom_toast.dart';

class CategoryMessagesSheet extends StatefulWidget {
  final List<AppTransaction> results;
  final String categoryName;
  final Function(AppTransaction) onMessageSelected;

  const CategoryMessagesSheet({
    super.key,
    required this.results,
    required this.categoryName,
    required this.onMessageSelected,
  });

  @override
  State<CategoryMessagesSheet> createState() => _CategoryMessagesSheetState();
}

class _CategoryMessagesSheetState extends State<CategoryMessagesSheet> {
  String? _selectedTxId;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  Color _getAvatarColor(String merchant) {
    final colors = [
      const Color(0xFF007AFF),
      const Color(0xFF34C759),
      const Color(0xFFFF9500),
      const Color(0xFFAF52DE),
      const Color(0xFFFF2D55),
      const Color(0xFF5856D6),
      const Color(0xFF00C7BE),
      const Color(0xFF30B0C7),
    ];
    final int hash = merchant
        .split('')
        .fold(0, (prev, char) => prev + char.codeUnitAt(0));
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.8,
      minChildSize: 0.15,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.15, 0.3, 0.8],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey4,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${widget.categoryName} Transactions',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: CupertinoColors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.clear,
                          size: 20,
                          color: CupertinoColors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: widget.results.isEmpty
                    ? EmptyStateWidget(
                        animationPath: emptyLottieAnimation,
                        message: 'No messages under "${widget.categoryName}"',
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: widget.results.length,
                        itemBuilder: (context, index) {
                          final tx = widget.results[index];
                          final isSelected = _selectedTxId == tx.id;
                          final bool needsMapping = tx.latitude == null;
                          final String timeAgo = _getTimeAgo(tx.timestamp);
                          final String initial = tx.merchant.isNotEmpty
                              ? tx.merchant[0].toUpperCase()
                              : '?';

                          return Column(
                            children: [
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  if (needsMapping) {
                                    showCustomToast(
                                      'Message has not yet been mapped',
                                    );
                                  } else {
                                    setState(() {
                                      _selectedTxId = tx.id;
                                    });
                                    // Close completely and navigate
                                    Navigator.pop(context);
                                    widget.onMessageSelected(tx);
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  color: isSelected
                                      ? CupertinoColors.systemGrey6
                                      : CupertinoColors.white,
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    16,
                                    12,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Builder(
                                        builder: (context) {
                                          final spendingService = context
                                              .read<SpendingService>();
                                          final categoryItem = spendingService
                                              .getCategoryByName(tx.category);

                                          final hasValidCategory =
                                              categoryItem != null;

                                          return Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: hasValidCategory
                                                  ? spendingService
                                                        .getCategoryColor(
                                                          tx.category!,
                                                        )
                                                  : _getAvatarColor(
                                                      tx.merchant,
                                                    ),
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
                                                      style:
                                                          GoogleFonts.spaceGrotesk(
                                                            color: Colors.white,
                                                            fontSize: 18,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    tx.merchant,
                                                    style:
                                                        GoogleFonts.spaceGrotesk(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: const Color(
                                                            0xFF1A1A1A,
                                                          ),
                                                        ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  tx.formattedAmount,
                                                  style:
                                                      GoogleFonts.spaceGrotesk(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: const Color(
                                                          0xFF1A1A1A,
                                                        ),
                                                      ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${needsMapping ? "Needs mapping" : "Mapped"} • $timeAgo',
                                              style: GoogleFonts.spaceGrotesk(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w400,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              tx.rawMessage,
                                              maxLines: 2,
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
                              ),
                              if (index < widget.results.length - 1)
                                Padding(
                                  padding: const EdgeInsets.only(left: 68),
                                  child: Divider(
                                    height: 1,
                                    thickness: 0.5,
                                    color: Colors.grey[200],
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
