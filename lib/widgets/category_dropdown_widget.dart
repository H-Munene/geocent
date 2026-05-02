import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mapbox_tut/models/category_item.dart';
import 'package:mapbox_tut/services/spending_service.dart';
import 'package:mapbox_tut/utils/categories.dart';
import 'package:provider/provider.dart';
import 'category_sheet.dart';
import 'custom_toast.dart';

class CategoryDropdownWidget extends StatelessWidget {
  final String transactionId;
  final String? currentCategory;
  final VoidCallback? onCategorySelected;

  const CategoryDropdownWidget({
    super.key,
    required this.transactionId,
    this.currentCategory,
    this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final spending = context.read<SpendingService>();
    final categories = spending.categories;
    final List<CategoryItem> availableIconsList = availableIcons.values
        .toList();

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final isSelected = currentCategory == cat.name;
                  return GestureDetector(
                    onTap: () {
                      spending.updateCategory(transactionId, cat.name);
                      if (onCategorySelected != null) {
                        onCategorySelected!();
                      } else {
                        // ********change made here

                        // Navigator.pop(context);
                        Navigator.popUntil(context, (route) => route.isFirst);
                      }
                      showCustomToast('Transaction successfully categorized');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      color: isSelected
                          ? CupertinoColors.systemGrey6
                          : CupertinoColors.white,
                      child: Row(
                        children: [
                          HugeIcon(icon: cat.icon, color: cat.color, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              cat.name,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: const Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(height: 1, color: CupertinoColors.systemGrey5),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                Navigator.popUntil(context, (route) => route.isFirst);

                showCupertinoSheet(
                  showDragHandle: true,
                  context: context,
                  builder: (context) => CreateCategorySheet(
                    transactionId: transactionId,
                    availableIcons: availableIconsList,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                width: double.infinity,
                alignment: Alignment.centerLeft,
                child: Text(
                  '+ Create New',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.systemBlue,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
