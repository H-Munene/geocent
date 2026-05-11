import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:geocent/models/category_item.dart';
import 'package:geocent/services/spending_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

class MapCategoryFilters extends StatelessWidget {
  final List<CategoryItem> categories;
  final String? selectedCategory;
  final Function(CategoryItem) onCategoryTap;

  const MapCategoryFilters({
    super.key,
    required this.categories,
    this.selectedCategory,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final spending = context.read<SpendingService>();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: categories.map((cat) {
          final isSelected = selectedCategory == cat.name;
          final catColor = spending.getCategoryColor(cat.name);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onCategoryTap(cat);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? catColor
                      : CupertinoColors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? catColor : CupertinoColors.systemGrey5,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HugeIcon(
                      icon: cat.icon,
                      color: isSelected
                          ? CupertinoColors.white
                          : CupertinoColors.black,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      cat.name,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? CupertinoColors.white
                            : CupertinoColors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
